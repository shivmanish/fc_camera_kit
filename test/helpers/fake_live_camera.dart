import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:fc_camera_kit/src/features/camera/data/datasources/fc_live_camera.dart';
import 'package:fc_camera_kit/src/features/camera/domain/entities/fc_camera_frame.dart';
import 'package:flutter/widgets.dart';

/// Fake camera that records calls.
/// [opening] and [taking] let a test hold `open()` and `takePicture()`.
final class FakeLiveCamera implements FcLiveCamera {
  Completer<void>? opening;
  Completer<void>? taking;
  Object? openError;
  Object? takeError;

  /// Thrown by `setFlash`, like a camera without a flash.
  Object? flashError;
  final calls = <String>[];
  void Function(FcCameraFrame frame)? listener;
  bool streaming = false;

  FcFlashMode? flash;

  @override
  double minZoom = 1;

  @override
  double maxZoom = 1;

  double? zoom;

  FcCameraResolution? resolution;
  FcCameraLens _lens = FcCameraLens.front;

  @override
  Set<FcCameraLens> lenses = {FcCameraLens.front};

  @override
  FcCameraLens get lens => _lens;

  bool? lockedLandscape;

  @override
  double? get sensorAspectRatio => 4 / 3;

  @override
  Future<void> lockOrientation({required bool landscape}) async =>
      lockedLandscape = landscape;

  @override
  Future<void> open({
    FcCameraLens lens = FcCameraLens.front,
    FcCameraResolution resolution = FcCameraResolution.analysis,
  }) async {
    calls.add('open');
    _lens = lens;
    this.resolution = resolution;
    final error = openError;
    if (error != null) throw error;
    if (!lenses.contains(lens)) {
      throw const CameraException('This device has no camera on that side.');
    }
    await opening?.future;
  }

  @override
  Future<void> setFlash(FcFlashMode mode) async {
    calls.add('flash:${mode.name}');
    final error = flashError;
    if (error != null) throw error;
    flash = mode;
  }

  @override
  Future<void> setZoom(double level) async => zoom = level;

  @override
  Widget buildPreview() => const SizedBox();

  @override
  Future<void> startFrames(void Function(FcCameraFrame frame) onFrame) async {
    calls.add('startFrames');
    listener = onFrame;
    streaming = true;
  }

  @override
  Future<void> stopFrames() async {
    calls.add('stopFrames');
    streaming = false;
  }

  @override
  Future<XFile> takePicture() async {
    calls.add('takePicture');
    streaming = false;
    await taking?.future;
    final error = takeError;
    if (error != null) throw error;
    return XFile('/photo.jpg');
  }

  @override
  Future<void> close() async {
    calls.add('close');
    streaming = false;
  }

  /// Bright enough to pass the low-light check.
  void emitFrame() => listener?.call(
    FcCameraFrame(
      bytes: Uint8List(64 * 64 * 3 ~/ 2)..fillRange(0, 64 * 64, 160),
      width: 64,
      height: 64,
      bytesPerRow: 64,
      rotationDegrees: 270,
      format: FcFrameFormat.nv21,
    ),
  );
}
