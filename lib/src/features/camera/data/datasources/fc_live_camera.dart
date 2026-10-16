import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/fc_camera_frame.dart';

/// Live camera: preview, analysis frames, photos; calls after [close] no-op.
abstract interface class FcLiveCamera {
  Future<void> open({
    FcCameraLens lens = FcCameraLens.front,
    FcCameraResolution resolution = FcCameraResolution.analysis,
  });

  /// Landscape sensor ratio, so above 1.
  double? get sensorAspectRatio;

  /// Filled by `open()` even when it fails.
  Set<FcCameraLens> get lenses;

  Future<void> setFlash(FcFlashMode mode);

  double get minZoom;
  double get maxZoom;

  Future<void> setZoom(double level);

  /// Locks preview, photos and frame rotation to the screen orientation.
  Future<void> lockOrientation({required bool landscape});

  FcCameraLens get lens;

  Widget buildPreview();

  Future<void> startFrames(void Function(FcCameraFrame frame) onFrame);

  Future<void> stopFrames();

  /// Stops frames; call [startFrames] again to resume.
  Future<XFile> takePicture();

  Future<void> close();
}
