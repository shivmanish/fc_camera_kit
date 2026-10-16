import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/image/edit/fc_crop_geometry.dart';
import '../../../../../core/image/edit/fc_photo_edit.dart';

/// The shot under review, and the editor's working copy while it is open.
final class FcPhotoReview extends Equatable {
  const FcPhotoReview({
    required this.photo,
    this.edit = FcPhotoEdit.none,
    this.aspect = FcCropAspect.free,
    this.draft,
  });

  final XFile photo;

  /// The crop and turn the user kept; shown on review, applied on use.
  final FcPhotoEdit edit;
  final FcCropAspect aspect;

  /// The editor's working copy; `null` while just reviewing. Cancel drops it,
  /// Done keeps it.
  final FcPhotoDraft? draft;

  bool get editing => draft != null;

  @override
  List<Object?> get props => [photo.path, edit, aspect, draft];
}

final class FcPhotoDraft extends Equatable {
  const FcPhotoDraft({
    this.edit = FcPhotoEdit.none,
    this.aspect = FcCropAspect.free,
  });

  final FcPhotoEdit edit;
  final FcCropAspect aspect;

  /// Nothing to reset.
  bool get isPristine => edit.isNone && aspect == FcCropAspect.free;

  @override
  List<Object?> get props => [edit, aspect];
}

/// What the camera hands back: the accepted shot and how to turn and crop it.
final class FcReviewedPhoto extends Equatable {
  const FcReviewedPhoto(
    this.file, {
    this.edit = FcPhotoEdit.none,
    this.takenAt,
  });

  final XFile file;
  final FcPhotoEdit edit;

  /// When the shutter was pressed; `null` for a gallery pick.
  final DateTime? takenAt;

  @override
  List<Object?> get props => [file.path, edit, takenAt];
}
