import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/image/edit/fc_crop_geometry.dart';
import '../../../../../core/image/edit/fc_photo_edit.dart';

final class FcPhotoReview extends Equatable {
  const FcPhotoReview({
    required this.photo,
    this.edit = FcPhotoEdit.none,
    this.aspect = FcCropAspect.free,
    this.draft,
  });

  final XFile photo;

  final FcPhotoEdit edit;
  final FcCropAspect aspect;

  /// Editor working copy; `null` outside the editor.
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

  bool get isPristine => edit.isNone && aspect == FcCropAspect.free;

  @override
  List<Object?> get props => [edit, aspect];
}

final class FcReviewedPhoto extends Equatable {
  const FcReviewedPhoto(
    this.file, {
    this.edit = FcPhotoEdit.none,
    this.takenAt,
  });

  final XFile file;
  final FcPhotoEdit edit;

  /// `null` for a gallery pick.
  final DateTime? takenAt;

  @override
  List<Object?> get props => [file.path, edit, takenAt];
}
