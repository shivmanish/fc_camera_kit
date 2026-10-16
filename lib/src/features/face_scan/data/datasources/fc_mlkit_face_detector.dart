import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/error/fc_camera_exception.dart';
import '../../../camera/domain/entities/fc_camera_frame.dart';
import '../../domain/entities/fc_face_observation.dart';
import '../../domain/repositories/fc_face_detector.dart';
import '../models/fc_face_observation_model.dart';

/// On-device face detection with ML Kit, tuned for speed: only eye-open
/// classification and tracking, no landmarks or contours.
final class FcMlKitFaceDetector implements FcFaceDetector {
  FcMlKitFaceDetector()
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableTracking: true,
          minFaceSize: 0.15,
        ),
      );

  final FaceDetector _detector;
  bool _closed = false;

  @override
  Future<List<FcFaceObservation>> detect(FcCameraFrame frame) async {
    if (_closed) return const [];
    try {
      final faces = await _detector.processImage(
        InputImage.fromBytes(
          bytes: frame.bytes,
          metadata: InputImageMetadata(
            size: Size(frame.width.toDouble(), frame.height.toDouble()),
            rotation: _rotation(frame.rotationDegrees),
            format: switch (frame.format) {
              FcFrameFormat.nv21 => InputImageFormat.nv21,
              FcFrameFormat.bgra8888 => InputImageFormat.bgra8888,
            },
            bytesPerRow: frame.bytesPerRow,
          ),
        ),
      );
      return [
        for (final face in faces)
          FcFaceObservationModel.fromMlKit(
            face,
            uprightWidth: frame.uprightWidth,
            uprightHeight: frame.uprightHeight,
          ),
      ];
    } catch (error, stackTrace) {
      throw ImageProcessingException(
        'Face detection failed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _detector.close();
  }

  static InputImageRotation _rotation(int degrees) => switch (degrees) {
    90 => InputImageRotation.rotation90deg,
    180 => InputImageRotation.rotation180deg,
    270 => InputImageRotation.rotation270deg,
    _ => InputImageRotation.rotation0deg,
  };
}
