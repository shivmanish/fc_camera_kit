import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/src/features/camera/data/datasources/fc_live_camera.dart';
import 'package:fc_camera_kit/src/features/camera/domain/entities/fc_camera_frame.dart';
import 'package:flutter/widgets.dart';

/// Records every call; [opening] lets a test hold `open()` mid-flight.
final class FakeLiveCamera implements FcLiveCamera {
  Completer<void>? opening;
  Object? openError;
  final calls = <String>[];
  void Function(FcCameraFrame frame)? listener;
  bool streaming = false;

  @override
  FcCameraLens get lens => FcCameraLens.front;

  /// The last orientation the camera was locked to.
  bool? lockedLandscape;

  @override
  double? get sensorAspectRatio => 4 / 3;

  @override
  Future<void> lockOrientation({required bool landscape}) async =>
      lockedLandscape = landscape;

  @override
  Future<void> open({FcCameraLens lens = FcCameraLens.front}) async {
    calls.add('open');
    final error = openError;
    if (error != null) throw error;
    await opening?.future;
  }

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
    return XFile('/photo.jpg');
  }

  @override
  Future<void> close() async {
    calls.add('close');
    streaming = false;
  }

  /// A bright frame, so the "too dark" check passes.
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
