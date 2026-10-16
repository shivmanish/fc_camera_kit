import '../../domain/entities/fc_camera_frame.dart';

/// Clockwise degrees that turn a raw frame upright, from ML Kit's recipe.
///
/// iOS frames already follow the sensor; Android ones also need the device
/// rotation, added for the front lens (it is mirrored) and subtracted for
/// the back one.
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
