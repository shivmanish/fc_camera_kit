import 'dart:ui';

import 'package:cross_file/cross_file.dart';

import '../../../../../core/config/fc_cubit.dart';
import '../../../../../core/image/edit/fc_crop_geometry.dart';
import '../../../../../core/image/fc_image_store.dart';
import 'fc_photo_review_state.dart';

/// Photo review; deletes the file unless accepted. Edits never touch pixels.
class FcPhotoReviewCubit extends FcCubit<FcPhotoReview?, void, void> {
  FcPhotoReviewCubit() : super(initialState: null);

  bool _accepted = false;
  DateTime? _takenAt;

  void review(XFile photo, {DateTime? takenAt}) {
    _takenAt = takenAt;
    safeEmit(FcPhotoReview(photo: photo));
  }

  Future<void> retake() async {
    final review = state;
    if (review == null) return;
    safeEmit(null);
    await FcImageStore.deleteQuietly(review.photo.path);
  }

  /// The caller owns the file from here.
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

  void rotateLeft() => _updateDraft(
    (draft) =>
        FcPhotoDraft(edit: draft.edit.rotatedLeft(), aspect: draft.aspect),
  );

  /// Starts from the largest centred crop of [aspect]; [photo] is upright.
  void chooseAspect(FcCropAspect aspect, Size photo) => _updateDraft((draft) {
    final ratio = FcCropGeometry.ratioOf(aspect, draft.edit.turn(photo));
    return FcPhotoDraft(
      edit: ratio == null
          ? draft.edit
          : draft.edit.withCrop(FcCropGeometry.fit(ratio)),
      aspect: aspect,
    );
  });

  /// [delta] is in fractions of the turned photo.
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
