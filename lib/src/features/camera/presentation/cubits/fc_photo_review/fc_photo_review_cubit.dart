import 'dart:ui';

import 'package:cross_file/cross_file.dart';

import '../../../../../core/config/fc_cubit.dart';
import '../../../../../core/image/edit/fc_crop_geometry.dart';
import '../../../../../core/image/fc_image_store.dart';
import 'fc_photo_review_state.dart';

/// The shot waiting for the user's verdict, and its crop and turn; `null`
/// while the camera is live.
///
/// Owns the raw file until it is accepted: a retake, or leaving the camera
/// without using it, deletes it, so rejected shots never pile up on disk.
///
/// Edits stay numbers: nothing here touches pixels, so editing is instant
/// and costs no quality.
class FcPhotoReviewCubit extends FcCubit<FcPhotoReview?, void, void> {
  FcPhotoReviewCubit() : super(initialState: null);

  bool _accepted = false;
  DateTime? _takenAt;

  /// [takenAt] is the shutter press; it travels with the shot to the stamp.
  void review(XFile photo, {DateTime? takenAt}) {
    _takenAt = takenAt;
    safeEmit(FcPhotoReview(photo: photo));
  }

  /// Discards the shot and goes back to the live camera.
  Future<void> retake() async {
    final review = state;
    if (review == null) return;
    safeEmit(null);
    await FcImageStore.deleteQuietly(review.photo.path);
  }

  /// Hands the shot over with its edit; from here the caller owns the file.
  FcReviewedPhoto? accept() {
    final review = state;
    if (review == null) return null;
    _accepted = true;
    return FcReviewedPhoto(review.photo, edit: review.edit, takenAt: _takenAt);
  }

  void openEditor() => _update(
    (review) => FcPhotoReview(
      photo: review.photo,
      edit: review.edit,
      aspect: review.aspect,
      draft: FcPhotoDraft(edit: review.edit, aspect: review.aspect),
    ),
  );

  /// A quarter turn anticlockwise; the crop turns with the photo and keeps
  /// its shape.
  void rotateLeft() => _updateDraft(
    (draft) =>
        FcPhotoDraft(edit: draft.edit.rotatedLeft(), aspect: draft.aspect),
  );

  /// Holds the crop to [aspect], starting from the largest centred crop of
  /// that shape. [photo] is the upright photo's size.
  void chooseAspect(FcCropAspect aspect, Size photo) => _updateDraft((draft) {
    final ratio = FcCropGeometry.ratioOf(aspect, draft.edit.turn(photo));
    return FcPhotoDraft(
      edit: ratio == null
          ? draft.edit
          : draft.edit.withCrop(FcCropGeometry.fit(ratio)),
      aspect: aspect,
    );
  });

  /// Moves or resizes the crop by [delta], in fractions of the turned photo.
  void dragCrop(FcCropHandle handle, Offset delta, Size photo) => _updateDraft((
    draft,
  ) {
    final ratio = FcCropGeometry.ratioOf(draft.aspect, draft.edit.turn(photo));
    return FcPhotoDraft(
      edit: draft.edit.withCrop(
        FcCropGeometry.drag(draft.edit.crop, handle, delta, ratio: ratio),
      ),
      aspect: draft.aspect,
    );
  });

  void resetDraft() => _updateDraft((_) => const FcPhotoDraft());

  void cancelEditor() => _update(
    (review) => FcPhotoReview(
      photo: review.photo,
      edit: review.edit,
      aspect: review.aspect,
    ),
  );

  void applyEditor() => _update((review) {
    final draft = review.draft;
    if (draft == null) return review;
    return FcPhotoReview(
      photo: review.photo,
      edit: draft.edit,
      aspect: draft.aspect,
    );
  });

  void _update(FcPhotoReview Function(FcPhotoReview review) change) {
    final review = state;
    if (review != null) safeEmit(change(review));
  }

  void _updateDraft(FcPhotoDraft Function(FcPhotoDraft draft) change) =>
      _update((review) {
        final draft = review.draft;
        if (draft == null) return review;
        return FcPhotoReview(
          photo: review.photo,
          edit: review.edit,
          aspect: review.aspect,
          draft: change(draft),
        );
      });

  @override
  Future<void> close() async {
    final review = state;
    if (review != null && !_accepted) {
      await FcImageStore.deleteQuietly(review.photo.path);
    }
    return super.close();
  }
}
