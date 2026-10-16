import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:fc_camera_kit/src/features/camera/domain/entities/fc_camera_frame.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_hint.dart';
import 'package:fc_camera_kit/src/features/face_scan/presentation/cubits/fc_face_detection/fc_face_detection_cubit.dart';
import 'package:fc_camera_kit/src/features/face_scan/presentation/cubits/fc_face_detection/fc_face_detection_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_face_detector.dart';

void main() {
  late FakeFaceDetector detector;
  late FcFaceDetectionCubit cubit;
  late DateTime now;

  final frame = FcCameraFrame(
    bytes: Uint8List(64 * 64 * 3 ~/ 2)..fillRange(0, 64 * 64, 160),
    width: 64,
    height: 64,
    bytesPerRow: 64,
    rotationDegrees: 270,
    format: FcFrameFormat.nv21,
  );

  setUp(() {
    now = DateTime(2026, 10, 2, 10);
    detector = FakeFaceDetector();
    cubit = FcFaceDetectionCubit(detector: detector, clock: () => now);
  });

  tearDown(() => cubit.close());

  Future<void> feed(double eyes) async {
    detector.faces = [framedFace(eyes: eyes)];
    cubit.onFrame(frame);
    await Future<void>.delayed(Duration.zero);
    now = now.add(const Duration(milliseconds: 100));
  }

  test('starts by asking for a face', () {
    expect(cubit.state, const FcFaceDetectionSearching(FcFaceHint.noFace));
  });

  test('turns ready after a blink, with the face to capture', () async {
    await feed(0.95);
    expect(cubit.state, const FcFaceDetectionSearching(FcFaceHint.blink));
    expect(cubit.readyFace, isNull);

    await feed(0.05);
    await feed(0.95);

    expect(cubit.state, const FcFaceDetectionReady());
    expect(cubit.readyFace, isNotNull);
  });

  test('drops frames while one is being analysed', () async {
    detector.gate = Completer<void>();
    cubit
      ..onFrame(frame)
      ..onFrame(frame)
      ..onFrame(frame);
    await Future<void>.delayed(Duration.zero);

    expect(detector.detections, 1);
    detector.gate!.complete();
  });

  test('ignores frames while paused, and resume needs a new blink', () async {
    await feed(0.95);
    await feed(0.05);
    await feed(0.95);
    expect(cubit.state, const FcFaceDetectionReady());

    cubit.pause();
    await feed(0.95);
    expect(detector.detections, 3);

    cubit.resume();
    expect(cubit.state, const FcFaceDetectionSearching(FcFaceHint.noFace));
    await feed(0.95);
    expect(cubit.state, const FcFaceDetectionSearching(FcFaceHint.blink));
  });

  test('a frame the detector fails on is skipped, not fatal', () async {
    detector.error = StateError('ML Kit hiccup');
    cubit.onFrame(frame);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, const FcFaceDetectionSearching(FcFaceHint.noFace));

    detector.error = null;
    await feed(0.95);
    expect(cubit.state, const FcFaceDetectionSearching(FcFaceHint.blink));
  });

  test('a detection that never answers is given up on', () {
    fakeAsync((async) {
      detector.gate = Completer<void>();
      cubit.onFrame(frame);
      async.elapse(const Duration(seconds: 3));

      detector
        ..gate = null
        ..faces = [framedFace()];
      cubit.onFrame(frame);
      async.flushMicrotasks();

      expect(detector.detections, 2);
      expect(cubit.state, const FcFaceDetectionSearching(FcFaceHint.blink));
    });
  });

  test('closing releases the detector', () async {
    await cubit.close();
    expect(detector.closed, isTrue);
  });
}
