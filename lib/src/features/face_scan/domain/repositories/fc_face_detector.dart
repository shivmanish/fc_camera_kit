import '../../../camera/domain/entities/fc_camera_frame.dart';
import '../entities/fc_face_observation.dart';

/// Finds faces in camera frames.
abstract interface class FcFaceDetector {
  Future<List<FcFaceObservation>> detect(FcCameraFrame frame);

  Future<void> close();
}
