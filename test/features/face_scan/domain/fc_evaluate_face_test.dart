import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_hint.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_observation.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_result.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_rules.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/usecases/fc_evaluate_face.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late FcEvaluateFace evaluate;

  setUp(() {
    now = DateTime(2026, 10, 2, 10);
    evaluate = FcEvaluateFace(clock: () => now);
  });

  void advance(int ms) => now = now.add(Duration(milliseconds: ms));

  const target = FcFaceRules.defaultTarget;

  /// A face centred in the oval, filling [fill] of its width, looking
  /// straight; offsets move it by fractions of the oval's size.
  FcFaceObservation face({
    double offsetX = 0,
    double offsetY = 0,
    double fill = 0.75,
    double eyes = 0.95,
    double? leftEye,
    double yaw = 0,
    int trackingId = 1,
  }) {
    final width = target.width * fill;
    final height = width * 1.2;
    final cx = target.centerX + offsetX * target.width;
    final cy = target.centerY + offsetY * target.height;
    return FcFaceObservation(
      box: FcFaceBox(
        left: cx - width / 2,
        top: cy - height / 2,
        width: width,
        height: height,
      ),
      pose: FcHeadPose(yaw: yaw),
      leftEyeOpen: leftEye ?? eyes,
      rightEyeOpen: eyes,
      trackingId: trackingId,
    );
  }

  FcFaceHint hint(List<FcFaceObservation> faces, {double luminance = 120}) =>
      evaluate(faces, luminance: luminance).hint;

  /// open → closed → open, with [closedFor] ms shut.
  FcFaceHint blink({int closedFor = 150, int trackingId = 1}) {
    hint([face(trackingId: trackingId)]);
    advance(50);
    hint([face(eyes: 0.05, trackingId: trackingId)]);
    advance(closedFor);
    return hint([face(trackingId: trackingId)]);
  }

  group('hints, in priority order', () {
    test('too dark wins over everything', () {
      expect(hint([face(), face()], luminance: 20), FcFaceHint.tooDark);
    });

    test('no face', () => expect(hint([]), FcFaceHint.noFace));

    test('more than one face', () {
      expect(hint([face(), face(trackingId: 2)]), FcFaceHint.multipleFaces);
    });

    test('off centre', () {
      expect(hint([face(offsetX: 0.3)]), FcFaceHint.notCentered);
      expect(hint([face(offsetY: 0.3)]), FcFaceHint.notCentered);
    });

    test('too small and too big', () {
      expect(hint([face(fill: 0.4)]), FcFaceHint.moveCloser);
      expect(hint([face(fill: 1.1)]), FcFaceHint.moveBack);
    });

    test('turned away', () {
      expect(hint([face(yaw: 30)]), FcFaceHint.lookStraight);
    });

    test('a valid face asks for a blink', () {
      expect(hint([face()]), FcFaceHint.blink);
    });
  });

  group('blink', () {
    test('open → closed → open turns it ready', () {
      expect(blink(), FcFaceHint.ready);
    });

    test('eyes held shut past the window is not a blink', () {
      expect(blink(closedFor: 2000), FcFaceHint.blink);
    });

    test('a wink (one eye) is not a blink', () {
      hint([face()]);
      advance(50);
      hint([face(leftEye: 0.05)]);
      advance(100);
      expect(hint([face()]), FcFaceHint.blink);
    });

    test('eyes closed from the start must open first', () {
      hint([face(eyes: 0.05)]);
      advance(100);
      expect(hint([face()]), FcFaceHint.blink);
    });

    test('a different face starts over', () {
      expect(blink(), FcFaceHint.ready);
      expect(hint([face(trackingId: 2)]), FcFaceHint.blink);
    });

    test('one stray frame keeps the blink', () {
      expect(blink(), FcFaceHint.ready);
      hint([]);
      advance(100);
      expect(hint([face()]), FcFaceHint.ready);
    });

    test('staying out of bounds loses the blink', () {
      expect(blink(), FcFaceHint.ready);
      hint([face(offsetX: 0.4)]);
      advance(800);
      hint([face(offsetX: 0.4)]);
      expect(hint([face()]), FcFaceHint.blink);
    });

    test('needs as many blinks as configured', () {
      evaluate = FcEvaluateFace(
        rules: const FcFaceRules(blinks: 2),
        clock: () => now,
      );
      expect(blink(), FcFaceHint.blink);
      advance(100);
      expect(blink(), FcFaceHint.ready);
    });

    test('reset forgets the blink', () {
      expect(blink(), FcFaceHint.ready);
      evaluate.reset();
      expect(hint([face()]), FcFaceHint.blink);
    });
  });

  test('judges framing against the target it is given', () {
    final moved = FcEvaluateFace(clock: () => now)
      ..target = const FcFaceBox(left: 0.1, top: 0.1, width: 0.3, height: 0.4);

    expect(
      moved([face()], luminance: 120).hint,
      FcFaceHint.notCentered,
      reason: 'a face in the old oval is outside the new one',
    );
  });
}
