import 'dart:async';

import 'package:fc_camera_kit/src/features/camera/domain/entities/fc_camera_frame.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_observation.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_result.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_rules.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/repositories/fc_face_detector.dart';

/// A face centred in [target] (the default oval unless given), filling 75 %
/// of its width.
FcFaceObservation framedFace({
  double eyes = 0.95,
  int trackingId = 1,
  FcFaceBox target = FcFaceRules.defaultTarget,
}) {
  final width = target.width * 0.75;
  final height = width * 1.2;
  return FcFaceObservation(
    box: FcFaceBox(
      left: target.centerX - width / 2,
      top: target.centerY - height / 2,
      width: width,
      height: height,
    ),
    leftEyeOpen: eyes,
    rightEyeOpen: eyes,
    trackingId: trackingId,
  );
}

/// Answers each detect() with [faces]; [gate] lets a test hold one open.
final class FakeFaceDetector implements FcFaceDetector {
  List<FcFaceObservation> faces = const [];
  Completer<void>? gate;
  Object? error;
  int detections = 0;
  bool closed = false;

  @override
  Future<List<FcFaceObservation>> detect(FcCameraFrame frame) async {
    detections++;
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return faces;
  }

  @override
  Future<void> close() async => closed = true;
}
