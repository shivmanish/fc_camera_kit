import '../../../camera/domain/entities/fc_camera_frame.dart';
import '../entities/fc_face_observation.dart';

abstract interface class FcFaceDetector {
  Future<List<FcFaceObservation>> detect(FcCameraFrame frame);

  Future<void> close();
}
