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

  group('as a photo camera', () {
    FcCameraCubit photo({bool useAnyLens = true}) => FcCameraCubit(
      camera: camera,
      lens: FcCameraLens.back,
      resolution: FcCameraResolution.photo,
      useAnyLens: useAnyLens,
      watchLifecycle: false,
    );

    FcCameraReady ready(FcCameraCubit cubit) => cubit.state as FcCameraReady;

    setUp(() => camera.lenses = {FcCameraLens.back});

    test('opens at photo resolution and never streams frames', () async {
      final cubit = photo();
      await cubit.start();

      expect(camera.resolution, FcCameraResolution.photo);
      expect(cubit.state, isA<FcCameraReady>());

      await cubit.capture();
      await cubit.resumeFrames();
      expect(camera.calls, isNot(contains('startFrames')));
      await cubit.close();
    });

    group('flash', () {
      test('starts on auto, as the system camera does', () async {
        final cubit = photo();
        await cubit.start();

        expect(camera.flash, FcFlashMode.auto);
        expect(
          cubit.state,
          const FcCameraReady(
            sensorAspect: 4 / 3,
            lens: FcCameraLens.back,
            flash: FcFlashMode.auto,
          ),
        );
        await cubit.close();
      });

      test('cycles auto, on, off and back to auto', () async {
        final cubit = photo();
        await cubit.start();

        final seen = <FcFlashMode?>[];
        for (var i = 0; i < 3; i++) {
          await cubit.cycleFlash();
          seen.add(ready(cubit).flash);
        }

        expect(seen, [FcFlashMode.on, FcFlashMode.off, FcFlashMode.auto]);
        expect(camera.flash, FcFlashMode.auto);
        await cubit.close();
      });

      test('is kept across a reopen', () async {
        final cubit = photo();
        await cubit.start();
        await cubit.cycleFlash();

        await cubit.start();

        expect(camera.flash, FcFlashMode.on);
        expect(ready(cubit).flash, FcFlashMode.on);
        await cubit.close();
      });

      test('a camera that refuses it never offers one', () async {
        camera.flashError = const CameraException('no flash unit');
        final cubit = photo();
        await cubit.start();

        expect(ready(cubit).flash, isNull);
        camera.calls.clear();
        await cubit.cycleFlash();
        expect(camera.calls, isEmpty);
        await cubit.close();
      });

      test('a refused mode is skipped, not fatal', () async {
        final cubit = photo();
        await cubit.start();

        camera.flashError = const CameraException('not this mode');
        await cubit.cycleFlash();

        expect(ready(cubit).flash, FcFlashMode.auto);
        await cubit.close();
      });

      test('the front camera has none, and the choice survives it', () async {
        camera.lenses = {FcCameraLens.front, FcCameraLens.back};
        final cubit = photo();
        await cubit.start();
        await cubit.cycleFlash();

        await cubit.switchLens();
        expect(ready(cubit).flash, isNull);

        await cubit.switchLens();
        expect(ready(cubit).flash, FcFlashMode.on);
        await cubit.close();
      });
    });

    group('zoom', () {
      setUp(() {
        camera
          ..minZoom = 1
          ..maxZoom = 8;
      });

      test('follows a pinch from where it began', () async {
        final cubit = photo();
        await cubit.start();

        cubit.beginZoom();
        await cubit.zoomBy(2);
        expect(camera.zoom, 2);

        // A second pinch carries on from 2×.
        cubit.beginZoom();
        await cubit.zoomBy(1.5);
        expect(camera.zoom, 3);
        await cubit.close();
      });

      test('stays inside the lens range', () async {
        final cubit = photo();
        await cubit.start();

        cubit.beginZoom();
        await cubit.zoomBy(20);
        expect(camera.zoom, 8);

        await cubit.zoomBy(0.01);
        expect(camera.zoom, 1);
        await cubit.close();
      });

      test('a lens without zoom ignores pinches', () async {
        camera.maxZoom = 1;
        final cubit = photo();
        await cubit.start();

        cubit.beginZoom();
        await cubit.zoomBy(3);
        expect(camera.zoom, isNull);
        await cubit.close();
      });

      test('is restored after a reopen, untouched until then', () async {
        final cubit = photo();
        await cubit.start();
        expect(camera.zoom, isNull);

        cubit.beginZoom();
        await cubit.zoomBy(4);
        camera.zoom = null;

        await cubit.start();
        expect(camera.zoom, 4);
        await cubit.close();
      });
    });

    group('lenses', () {
      test('switchLens reopens on the other side', () async {
        camera.lenses = {FcCameraLens.front, FcCameraLens.back};
        final cubit = photo();
        await cubit.start();
        expect(ready(cubit).canSwitchLens, isTrue);

        await cubit.switchLens();

        expect(cubit.lens, FcCameraLens.front);
        expect(camera.lens, FcCameraLens.front);
        expect(
          cubit.state,
          const FcCameraReady(sensorAspect: 4 / 3, canSwitchLens: true),
        );
        await cubit.close();
      });

      test('switchLens does nothing with one camera', () async {
        final cubit = photo();
        await cubit.start();
        camera.calls.clear();

        await cubit.switchLens();

        expect(camera.calls, isEmpty);
        expect(cubit.lens, FcCameraLens.back);
        await cubit.close();
      });

      test('a missing side falls back to the one the device has', () async {
        camera.lenses = {FcCameraLens.front};
        final cubit = photo();
        await cubit.start();

        expect(cubit.lens, FcCameraLens.front);
        expect(ready(cubit).lens, FcCameraLens.front);
        await cubit.close();
      });

      test('without useAnyLens a missing side is an error', () async {
        camera.lenses = {FcCameraLens.front};
        final cubit = photo(useAnyLens: false);
        await cubit.start();

        expect(cubit.state, isA<FcCameraError>());
        await cubit.close();
      });
    });

    test('capture marks the shutter busy until the photo is back', () async {
      camera
        ..lenses = {FcCameraLens.front, FcCameraLens.back}
        ..taking = Completer<void>();
      final cubit = photo();
      await cubit.start();

      final shot = cubit.capture();
      expect(ready(cubit).capturing, isTrue);

      // Neither the lens nor the flash may change under a photo.
      await cubit.switchLens();
      await cubit.cycleFlash();
      expect(camera.calls.where((c) => c == 'open'), hasLength(1));
      expect(camera.flash, FcFlashMode.auto);

      camera.taking!.complete();
      expect((await shot).isSuccess, isTrue);
      expect(ready(cubit).capturing, isFalse);
      await cubit.close();
    });

    test('a failed capture keeps the camera live', () async {
      camera.takeError = const CameraException('busy');
      final cubit = photo();
      await cubit.start();

      final shot = await cubit.capture();

      expect(shot.failureOrNull, isA<CameraFailure>());
      expect(ready(cubit).capturing, isFalse);
      await cubit.close();
    });
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
