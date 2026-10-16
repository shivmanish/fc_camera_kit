import '../../domain/entities/fc_camera_frame.dart';

/// Android adds device rotation for the mirrored front lens, else subtracts.
int fcFrameRotation({
  required bool isIOS,
  required int sensorOrientation,
  required int deviceRotation,
  required FcCameraLens lens,
}) {
  if (isIOS) return sensorOrientation % 360;
  return switch (lens) {
    FcCameraLens.front => (sensorOrientation + deviceRotation) % 360,
    FcCameraLens.back => (sensorOrientation - deviceRotation + 360) % 360,
  };
}
