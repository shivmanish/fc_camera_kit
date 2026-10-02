import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:fc_camera_kit/src/features/camera/domain/entities/fc_face_frame_geometry.dart';
import 'package:fc_camera_kit/src/features/camera/presentation/widgets/fc_camera_shutter.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_capture.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_hint.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_observation.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_rules.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/repositories/fc_face_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_face_detector.dart';
import '../../../helpers/fake_live_camera.dart';

class _MockRepository extends Mock implements FcFaceRepository {}

void main() {
  late FakeLiveCamera camera;
  late FakeFaceDetector detector;
  late _MockRepository repository;
  late GlobalKey<NavigatorState> navigatorKey;
  late List<bool> savedMirrored;

  final image = FcProcessedImage(
    file: XFile('/out/selfie.jpg'),
    sizeBytes: 900,
    width: 720,
    height: 960,
    wasCompressed: true,
    quality: 85,
    stamped: false,
  );

  setUpAll(() {
    registerFallbackValue(
      FcFaceCapture(
        file: XFile(''),
        capturedAt: DateTime(2026),
        face: framedFace(),
      ),
    );
  });

  setUp(() async {
    FcCameraKit.reset();
    await FcCameraKit.instance.init();
    FcFaceScanPage.debugPermissionGate = (_, _) async => true;
    savedMirrored = [];
    FcFaceScanPage.debugSaveFrame = (frame, {required mirror}) async {
      savedMirrored.add(mirror);
      return XFile('/raw/frame.bmp');
    };
    camera = FakeLiveCamera();
    detector = FakeFaceDetector();
    repository = _MockRepository();
    navigatorKey = GlobalKey<NavigatorState>();
    when(() => repository.discard(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    FcFaceScanPage.debugPermissionGate = null;
    FcFaceScanPage.debugSaveFrame = null;
    FcCameraKitFaceScan.debugCamera = null;
    FcCameraKitFaceScan.debugDetector = null;
    FcCameraKitFaceScan.debugRepository = null;
    FcCameraKit.reset();
  });

  void processReturns(Future<FcResult<FcProcessedImage>> Function() answer) =>
      when(
        () => repository.process(
          any(),
          maxBytes: any(named: 'maxBytes'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((invocation) {
        final onStage =
            invocation.namedArguments[#onStage] as void Function(FcImageStage)?;
        onStage?.call(FcImageStage.compressing);
        return answer();
      });

  // Spinners never settle, so advance time in fixed steps instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpHost(
    WidgetTester tester, {
    Size size = const Size(360, 780),
  }) {
    // A real phone in portrait by default.
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('host')),
      ),
    );
  }

  Future<Object?> open(FcFaceScanPage page) => navigatorKey.currentState!
      .push<Object?>(MaterialPageRoute(builder: (_) => page));

  FcFaceScanPage page({
    ValueChanged<FcFaceResult>? onCompleted,
    VoidCallback? onCancelled,
    ValueChanged<FcCameraFailure>? onFailed,
    bool? stamp,
    Duration autoCaptureAfter = Duration.zero,
  }) => FcFaceScanPage(
    camera: camera,
    detector: detector,
    repository: repository,
    stamp: stamp,
    autoCaptureAfter: autoCaptureAfter,
    onCompleted: onCompleted,
    onCancelled: onCancelled,
    onFailed: onFailed,
  );

  /// Shows an open face, closes the eyes, opens them: a blink.
  Future<void> blink(
    WidgetTester tester, {
    FcFaceBox target = FcFaceRules.defaultTarget,
  }) async {
    for (final eyes in [0.95, 0.05, 0.95]) {
      detector.faces = [framedFace(eyes: eyes, target: target)];
      camera.emitFrame();
      await tester.pump();
      await tester.pump();
    }
    await settle(tester);
  }

  FcCameraShutter shutter(WidgetTester tester) =>
      tester.widget(find.byType(FcCameraShutter));

  testWidgets('red until a blink, then green with the shutter enabled', (
    tester,
  ) async {
    await pumpHost(tester);
    unawaited(open(page()));
    await settle(tester);

    detector.faces = [framedFace()];
    camera.emitFrame();
    await settle(tester);
    expect(find.text(FcFaceHint.blink.message), findsOneWidget);
    expect(shutter(tester).onPressed, isNull);

    await blink(tester);
    expect(find.text(FcFaceHint.ready.message), findsOneWidget);
    expect(shutter(tester).onPressed, isNotNull);
  });

  testWidgets('capture shows the steps, then returns the result once', (
    tester,
  ) async {
    final processing = Completer<FcResult<FcProcessedImage>>();
    processReturns(() => processing.future);
    var completed = 0;

    await pumpHost(tester);
    final popped = open(page(onCompleted: (_) => completed++));
    await settle(tester);
    await blink(tester);

    await tester.tap(find.byType(FcCameraShutter));
    await settle(tester);
    expect(find.text('Preparing your photo'), findsOneWidget);
    expect(find.text(FcImageStage.compressing.label), findsOneWidget);
    expect(find.text(FcImageStage.writingMetadata.label), findsOneWidget);
    expect(find.text(FcImageStage.stamping.label), findsNothing);

    processing.complete(fcSuccess(image));
    await settle(tester);

    expect(completed, 1);
    final result = await popped;
    expect(result, isA<FcFaceResult>());
    expect((result! as FcFaceResult).file.path, image.file.path);
    expect(savedMirrored, [true]);
    expect(camera.calls, isNot(contains('takePicture')));
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets('with stamp on, lists "Adding the stamp" and passes the spec', (
    tester,
  ) async {
    final processing = Completer<FcResult<FcProcessedImage>>();
    processReturns(() => processing.future);

    await pumpHost(tester);
    unawaited(open(page(stamp: true)));
    await settle(tester);
    await blink(tester);
    await tester.tap(find.byType(FcCameraShutter));
    await settle(tester);

    expect(find.text(FcImageStage.stamping.label), findsOneWidget);
    final spec = verify(
      () => repository.process(
        any(),
        maxBytes: any(named: 'maxBytes'),
        writeMetadata: any(named: 'writeMetadata'),
        stamp: captureAny(named: 'stamp'),
        onStage: any(named: 'onStage'),
      ),
    ).captured.single;
    expect(spec, isA<FcStampSpec>());

    processing.complete(fcSuccess(image));
    await settle(tester);
  });

  testWidgets('a failure offers Try again, which goes back to the camera', (
    tester,
  ) async {
    processReturns(() async => fcFailure(const StorageFailure('disk full')));

    await pumpHost(tester);
    unawaited(open(page()));
    await settle(tester);
    await blink(tester);
    await tester.tap(find.byType(FcCameraShutter));
    await settle(tester);

    expect(find.text("Couldn't prepare your photo"), findsOneWidget);
    expect(find.byType(FcCameraShutter), findsOneWidget);
    expect(shutter(tester).onPressed, isNull);

    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(find.text(FcFaceHint.noFace.message), findsOneWidget);
    expect(camera.streaming, isTrue);
  });

  testWidgets('Close after a failure reports that failure once', (
    tester,
  ) async {
    processReturns(() async => fcFailure(const StorageFailure('disk full')));
    final failures = <FcCameraFailure>[];

    await pumpHost(tester);
    final popped = open(page(onFailed: failures.add));
    await settle(tester);
    await blink(tester);
    await tester.tap(find.byType(FcCameraShutter));
    await settle(tester);
    await tester.tap(find.text('Close'));
    await settle(tester);

    expect(failures, [const StorageFailure('disk full')]);
    expect(await popped, isNull);
  });

  testWidgets('the close button cancels once and releases the camera', (
    tester,
  ) async {
    var cancelled = 0;

    await pumpHost(tester);
    final popped = open(page(onCancelled: () => cancelled++));
    await settle(tester);
    await tester.tap(find.byType(FcCloseButton));
    await settle(tester);

    expect(cancelled, 1);
    expect(await popped, isNull);
    expect(camera.calls.last, 'close');
    expect(detector.closed, isTrue);
  });

  testWidgets('host clearing the stack cancels once and releases everything', (
    tester,
  ) async {
    var cancelled = 0;

    await pumpHost(tester);
    unawaited(open(page(onCancelled: () => cancelled++)));
    await settle(tester);

    unawaited(
      navigatorKey.currentState!.pushAndRemoveUntil<void>(
        MaterialPageRoute(builder: (_) => const Text('login')),
        (_) => false,
      ),
    );
    await settle(tester);

    expect(cancelled, 1);
    expect(camera.calls.last, 'close');
    expect(detector.closed, isTrue);
  });

  testWidgets('close while the tick shows hands over the result', (
    tester,
  ) async {
    processReturns(() async => fcSuccess(image));
    var completed = 0;
    var cancelled = 0;

    await pumpHost(tester);
    final popped = open(
      page(onCompleted: (_) => completed++, onCancelled: () => cancelled++),
    );
    await settle(tester);
    await blink(tester);
    await tester.tap(find.byType(FcCameraShutter));
    await tester.pump();
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.byType(FcCloseButton));
    await settle(tester);

    expect((completed, cancelled), (1, 0));
    expect(await popped, isA<FcFaceResult>());
  });

  testWidgets('processing stays on screen while the app is away', (
    tester,
  ) async {
    final processing = Completer<FcResult<FcProcessedImage>>();
    processReturns(() => processing.future);

    await pumpHost(tester);
    unawaited(open(page()));
    await settle(tester);
    await blink(tester);
    await tester.tap(find.byType(FcCameraShutter));
    await settle(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(tester);

    expect(camera.calls.last, 'close');
    expect(find.text('Preparing your photo'), findsOneWidget);
    expect(find.text(FcImageStage.compressing.label), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    processing.complete(fcSuccess(image));
    await settle(tester);
  });

  testWidgets('a double tap on the shutter takes one photo', (tester) async {
    final processing = Completer<FcResult<FcProcessedImage>>();
    processReturns(() => processing.future);

    await pumpHost(tester);
    unawaited(open(page()));
    await settle(tester);
    await blink(tester);

    await tester.tap(find.byType(FcCameraShutter));
    await tester.tap(find.byType(FcCameraShutter), warnIfMissed: false);
    await settle(tester);

    expect(savedMirrored, hasLength(1));
    expect(find.text('Preparing your photo'), findsOneWidget);

    processing.complete(fcSuccess(image));
    await settle(tester);
  });

  testWidgets('the camera follows the screen orientation', (tester) async {
    await pumpHost(tester, size: const Size(780, 360));
    unawaited(open(page()));
    await settle(tester);
    expect(camera.lockedLandscape, isTrue);

    tester.view.physicalSize = const Size(360, 780) * 3;
    await settle(tester);
    expect(camera.lockedLandscape, isFalse);
  });

  for (final (name, size) in [
    ('short phone', const Size(320, 568)),
    ('tablet', const Size(820, 1180)),
    ('landscape phone', const Size(780, 360)),
  ]) {
    testWidgets('$name: steps and failure buttons fit without overflow', (
      tester,
    ) async {
      final processing = Completer<FcResult<FcProcessedImage>>();
      processReturns(() => processing.future);

      await pumpHost(tester, size: size);
      unawaited(open(page(stamp: true)));
      await settle(tester);
      // The oval this screen draws, mapped into the frame like the cubit does.
      final oval = FcFaceFrameGeometry.ovalInFrame(
        size,
        FcFaceFrameGeometry.uprightAspect(
          4 / 3,
          landscape: size.width > size.height,
        ),
      );
      await blink(
        tester,
        target: FcFaceBox(
          left: oval.left,
          top: oval.top,
          width: oval.width,
          height: oval.height,
        ),
      );
      await tester.tap(find.byType(FcCameraShutter));
      await settle(tester);
      expect(find.text(FcImageStage.stamping.label), findsOneWidget);

      processing.complete(fcFailure(const StorageFailure('disk full')));
      await settle(tester);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('green for the countdown takes the photo by itself', (
    tester,
  ) async {
    final processing = Completer<FcResult<FcProcessedImage>>();
    processReturns(() => processing.future);

    await pumpHost(tester);
    unawaited(open(page(autoCaptureAfter: const Duration(seconds: 1))));
    await settle(tester);
    await blink(tester);

    expect(find.text('Preparing your photo'), findsOneWidget);
    expect(savedMirrored, [true]);
    processing.complete(fcSuccess(image));
    await settle(tester);
  });

  testWidgets('leaving green before the countdown ends cancels it', (
    tester,
  ) async {
    await pumpHost(tester);
    unawaited(open(page(autoCaptureAfter: const Duration(seconds: 2))));
    await settle(tester);
    await blink(tester);
    expect(find.text('Hold still, taking your photo'), findsOneWidget);

    detector.faces = [];
    camera.emitFrame();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);

    expect(savedMirrored, isEmpty);
  });

  testWidgets('a hint that changes and changes back never crashes', (
    tester,
  ) async {
    await pumpHost(tester);
    unawaited(open(page()));
    await settle(tester);

    for (final faces in [
      [framedFace()],
      <FcFaceObservation>[],
      [framedFace()],
      <FcFaceObservation>[],
      [framedFace()],
    ]) {
      detector.faces = faces;
      camera.emitFrame();
      await tester.pump(const Duration(milliseconds: 60));
    }
    await settle(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('denied permission ends with a PermissionFailure', (
    tester,
  ) async {
    FcFaceScanPage.debugPermissionGate = (_, _) async => false;
    final failures = <FcCameraFailure>[];

    await pumpHost(tester);
    final popped = open(page(onFailed: failures.add));
    await settle(tester);

    expect(failures.single, isA<PermissionFailure>());
    expect(await popped, isNull);
    expect(camera.calls, isEmpty);
  });

  group('FcCameraKit.scanFace', () {
    setUp(() {
      FcCameraKitFaceScan.debugCamera = camera;
      FcCameraKitFaceScan.debugDetector = detector;
      FcCameraKitFaceScan.debugRepository = repository;
    });

    testWidgets('returns the result after a blink and a capture', (
      tester,
    ) async {
      processReturns(() async => fcSuccess(image));
      await pumpHost(tester);

      final pending = FcCameraKit.instance.scanFace(
        navigatorKey.currentContext!,
      );
      await settle(tester);
      await blink(tester);
      await tester.tap(find.byType(FcCameraShutter));
      await settle(tester);

      expect((await pending).valueOrNull?.file.path, image.file.path);
      expect(find.text('host'), findsOneWidget);
    });

    testWidgets('fails cleanly when init() was not called', (tester) async {
      FcCameraKit.reset();
      await pumpHost(tester);

      final result = await FcCameraKit.instance.scanFace(
        navigatorKey.currentContext!,
      );

      expect(result.failureOrNull, isA<ConfigurationFailure>());
    });

    testWidgets('returns Cancelled and frees itself when the stack clears', (
      tester,
    ) async {
      await pumpHost(tester);
      final first = FcCameraKit.instance.scanFace(navigatorKey.currentContext!);
      await settle(tester);

      unawaited(
        navigatorKey.currentState!.pushAndRemoveUntil<void>(
          MaterialPageRoute(builder: (_) => const Text('login')),
          (_) => false,
        ),
      );
      await settle(tester);

      expect((await first).failureOrNull, isA<CancelledFailure>());
      final second = FcCameraKit.instance.scanFace(
        navigatorKey.currentContext!,
      );
      expect(identical(first, second), isFalse);
      await settle(tester);
    });
  });

  test('the camera feature never imports face_scan', () {
    final offenders = Directory('lib/src/features/camera')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.readAsStringSync().contains('face_scan/'))
        .map((file) => file.path);

    expect(offenders, isEmpty);
  });
}
