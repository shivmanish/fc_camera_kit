import 'dart:async';
import 'dart:typed_data';

import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:fc_camera_kit/src/features/camera/data/datasources/fc_frame_rotation.dart';
import 'package:fc_camera_kit/src/features/camera/domain/entities/fc_camera_frame.dart';
import 'package:fc_camera_kit/src/features/camera/presentation/cubits/fc_camera/fc_camera_cubit.dart';
import 'package:fc_camera_kit/src/features/camera/presentation/cubits/fc_camera/fc_camera_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_live_camera.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLiveCamera camera;
  late List<FcCameraFrame> frames;

  setUp(() {
    camera = FakeLiveCamera();
    frames = [];
  });

  FcCameraCubit build({bool lifecycle = false}) => FcCameraCubit(
    camera: camera,
    onFrame: frames.add,
    watchLifecycle: lifecycle,
  );

  test('opens, starts frames and becomes ready', () async {
    final cubit = build();
    await cubit.start();

    expect(cubit.state, const FcCameraReady(sensorAspect: 4 / 3));
    expect(camera.calls, ['open', 'startFrames']);

    camera.emitFrame();
    expect(frames, hasLength(1));
    await cubit.close();
  });

  test('a denied camera ends in a permission error', () async {
    camera.openError = const PermissionException(
      'denied',
      permanentlyDenied: true,
    );
    final cubit = build();
    await cubit.start();

    expect(
      cubit.state,
      isA<FcCameraError>().having(
        (state) => state.failure,
        'failure',
        isA<PermissionFailure>()
            .having((f) => f.permission, 'permission', 'camera')
            .having((f) => f.permanentlyDenied, 'permanentlyDenied', true),
      ),
    );
    await cubit.close();
  });

  test('capture stops frames until resumeFrames', () async {
    final cubit = build();
    await cubit.start();

    final photo = await cubit.capture();
    expect(photo.valueOrNull?.path, '/photo.jpg');
    expect(camera.streaming, isFalse);

    await cubit.resumeFrames();
    expect(camera.streaming, isTrue);
    await cubit.close();
  });

  test('a second capture while one is running is refused', () async {
    final cubit = build();
    await cubit.start();

    final first = cubit.capture();
    final second = await cubit.capture();

    expect(second.failureOrNull, isA<CameraFailure>());
    expect((await first).isSuccess, isTrue);
    expect(camera.calls.where((c) => c == 'takePicture'), hasLength(1));
    await cubit.close();
  });

  test('capture before the camera is ready fails cleanly', () async {
    final cubit = build();

    expect((await cubit.capture()).failureOrNull, isA<CameraFailure>());
    await cubit.close();
  });

  testWidgets('releases when the app goes inactive and reopens on resume', (
    tester,
  ) async {
    final cubit = build(lifecycle: true);
    await cubit.start();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(cubit.state, const FcCameraPaused());
    expect(camera.calls.last, 'close');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(cubit.state, const FcCameraReady(sensorAspect: 4 / 3));
    expect(camera.streaming, isTrue);
    await cubit.close();
  });

  testWidgets('reopening after a capture keeps frames stopped', (tester) async {
    final cubit = build(lifecycle: true);
    await cubit.start();
    await cubit.capture();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(cubit.state, isA<FcCameraReady>());
    expect(camera.streaming, isFalse);
    await cubit.close();
  });

  testWidgets('a start interrupted by the app going inactive is abandoned', (
    tester,
  ) async {
    camera.opening = Completer<void>();
    final cubit = build(lifecycle: true);
    final starting = cubit.start();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    camera.opening!.complete();
    await starting;

    expect(cubit.state, const FcCameraPaused());
    expect(camera.calls, isNot(contains('startFrames')));
    await cubit.close();
  });

  test('close releases the camera and ignores later calls', () async {
    final cubit = build();
    await cubit.start();
    await cubit.close();

    expect(camera.calls.last, 'close');
    await cubit.start();
    expect(camera.calls.where((c) => c == 'open'), hasLength(1));
  });

  group('fcFrameRotation', () {
    test('iOS follows the sensor', () {
      expect(
        fcFrameRotation(
          isIOS: true,
          sensorOrientation: 90,
          deviceRotation: 0,
          lens: FcCameraLens.front,
        ),
        90,
      );
    });

    test('Android front adds the device rotation, back subtracts it', () {
      expect(
        fcFrameRotation(
          isIOS: false,
          sensorOrientation: 270,
          deviceRotation: 90,
          lens: FcCameraLens.front,
        ),
        0,
      );
      expect(
        fcFrameRotation(
          isIOS: false,
          sensorOrientation: 90,
          deviceRotation: 270,
          lens: FcCameraLens.back,
        ),
        180,
      );
    });
  });

  group('FcCameraFrame', () {
    test('reports the upright size for sideways frames', () {
      final frame = FcCameraFrame(
        bytes: Uint8List(0),
        width: 1280,
        height: 720,
        bytesPerRow: 1280,
        rotationDegrees: 270,
        format: FcFrameFormat.nv21,
      );

      expect((frame.uprightWidth, frame.uprightHeight), (720, 1280));
    });

    test('samples brightness from the luma plane', () {
      final frame = FcCameraFrame(
        bytes: Uint8List(64 * 64 * 3 ~/ 2)..fillRange(0, 64 * 64, 200),
        width: 64,
        height: 64,
        bytesPerRow: 64,
        rotationDegrees: 0,
        format: FcFrameFormat.nv21,
      );

      expect(frame.sampleLuminance(), closeTo(200, 0.1));
    });
  });
}
