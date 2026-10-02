import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/fc_camera_frame.dart';

/// A live camera: preview, analysis frames and one photo at a time.
///
/// Throws `FcCameraException`s. Every method is safe to call in any order
/// after [close]; they become no-ops rather than throwing.
abstract interface class FcLiveCamera {
  Future<void> open({FcCameraLens lens = FcCameraLens.front});

  /// Width ÷ height of the sensor's frames (landscape, so above 1); `null`
  /// until opened.
  double? get sensorAspectRatio;

  /// Locks the preview, photos and frame rotation to the screen's
  /// orientation, so all three match what the user sees.
  Future<void> lockOrientation({required bool landscape});

  FcCameraLens get lens;

  Widget buildPreview();

  /// Delivers frames until [stopFrames]; the caller drops ones it can't keep
  /// up with.
  Future<void> startFrames(void Function(FcCameraFrame frame) onFrame);

  Future<void> stopFrames();

  /// Stops frames first; they stay stopped until [startFrames] again.
  Future<XFile> takePicture();

  Future<void> close();
}
