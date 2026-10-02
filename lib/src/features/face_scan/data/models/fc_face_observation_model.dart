import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../domain/entities/fc_face_observation.dart';
import '../../domain/entities/fc_face_result.dart';

/// ML Kit's [Face] read into the plugin-free entity.
final class FcFaceObservationModel extends FcFaceObservation {
  const FcFaceObservationModel({
    required super.box,
    super.pose,
    super.leftEyeOpen,
    super.rightEyeOpen,
    super.trackingId,
  });

  /// [uprightWidth] and [uprightHeight] are the frame's size after rotation,
  /// the space ML Kit reports the box in.
  factory FcFaceObservationModel.fromMlKit(
    Face face, {
    required int uprightWidth,
    required int uprightHeight,
  }) {
    final rect = face.boundingBox;
    return FcFaceObservationModel(
      box: FcFaceBox(
        left: rect.left / uprightWidth,
        top: rect.top / uprightHeight,
        width: rect.width / uprightWidth,
        height: rect.height / uprightHeight,
      ),
      pose: FcHeadPose(
        yaw: face.headEulerAngleY ?? 0,
        pitch: face.headEulerAngleX ?? 0,
        roll: face.headEulerAngleZ ?? 0,
      ),
      leftEyeOpen: face.leftEyeOpenProbability,
      rightEyeOpen: face.rightEyeOpenProbability,
      trackingId: face.trackingId,
    );
  }
}
