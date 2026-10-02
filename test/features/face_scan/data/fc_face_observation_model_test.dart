import 'dart:ui';

import 'package:fc_camera_kit/src/features/face_scan/data/models/fc_face_observation_model.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

void main() {
  test('normalises the box to the upright frame and maps the angles', () {
    final model = FcFaceObservationModel.fromMlKit(
      Face(
        boundingBox: const Rect.fromLTWH(180, 320, 360, 480),
        landmarks: const {},
        contours: const {},
        headEulerAngleX: 4,
        headEulerAngleY: -8,
        headEulerAngleZ: 2,
        leftEyeOpenProbability: 0.9,
        rightEyeOpenProbability: 0.8,
        trackingId: 7,
      ),
      uprightWidth: 720,
      uprightHeight: 1280,
    );

    expect(
      model.box,
      const FcFaceBox(left: 0.25, top: 0.25, width: 0.5, height: 0.375),
    );
    expect(model.pose, const FcHeadPose(yaw: -8, pitch: 4, roll: 2));
    expect((model.leftEyeOpen, model.rightEyeOpen), (0.9, 0.8));
    expect(model.trackingId, 7);
  });

  test('missing angles read as straight', () {
    final model = FcFaceObservationModel.fromMlKit(
      Face(
        boundingBox: const Rect.fromLTWH(0, 0, 10, 10),
        landmarks: const {},
        contours: const {},
      ),
      uprightWidth: 100,
      uprightHeight: 100,
    );

    expect(model.pose, const FcHeadPose());
    expect(model.leftEyeOpen, isNull);
  });
}
