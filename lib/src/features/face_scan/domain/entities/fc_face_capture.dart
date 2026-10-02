import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/image/metadata/fc_photo_metadata.dart';
import 'fc_face_observation.dart';

/// The selfie as taken, with everything known at that moment.
final class FcFaceCapture extends Equatable {
  const FcFaceCapture({
    required this.file,
    required this.capturedAt,
    required this.face,
    this.metadata,
  });

  /// Straight from the camera, before any processing.
  final XFile file;
  final DateTime capturedAt;

  /// The face that was green when the shutter was pressed.
  final FcFaceObservation face;
  final FcPhotoMetadata? metadata;

  @override
  List<Object?> get props => [file.path, capturedAt, face, metadata];
}
