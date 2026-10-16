import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/image/metadata/fc_photo_metadata.dart';
import 'fc_face_observation.dart';

final class FcFaceCapture extends Equatable {
  const FcFaceCapture({
    required this.file,
    required this.capturedAt,
    required this.face,
    this.metadata,
  });

  final XFile file;
  final DateTime capturedAt;

  /// The face that passed every check at shutter time.
  final FcFaceObservation face;
  final FcPhotoMetadata? metadata;

  @override
  List<Object?> get props => [file.path, capturedAt, face, metadata];
}
