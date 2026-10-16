import 'dart:async';
import 'dart:convert';

import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:fc_camera_kit/src/core/navigation/fc_navigator.dart';
import 'package:fc_camera_kit/src/features/camera/domain/entities/fc_camera_frame.dart';
import 'package:fc_camera_kit/src/features/camera/presentation/cubits/fc_photo_review/fc_photo_review_state.dart';
import 'package:fc_camera_kit/src/features/camera/presentation/pages/fc_photo_camera_page.dart';
import 'package:fc_camera_kit/src/features/camera/presentation/widgets/fc_camera_shutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_live_camera.dart';

void main() {
  late FakeLiveCamera camera;
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() {
    camera = FakeLiveCamera()..lenses = {FcCameraLens.back};
    navigatorKey = GlobalKey<NavigatorState>();
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    Size size = const Size(360, 780),
  }) {
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

  // A 1x1 PNG, so the review has real pixels without touching the disk.
  final photoImage = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    ),
  );

  /// Opens the camera the way the capture flow does.
  Future<FcReviewedPhoto?> open() => FcNavigator.push<FcReviewedPhoto>(
    navigatorKey.currentContext!,
    (_) => FcPhotoCameraPage(camera: camera, imageFor: (_) => photoImage),
  );

  // Spinners never settle, so advance time in fixed steps instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final shutter = find.byType(FcCameraShutter);

  testWidgets('opens the back camera at photo resolution', (tester) async {
    await pumpHost(tester);
    unawaited(open());
    await settle(tester);

    expect(camera.lens, FcCameraLens.back);
    expect(camera.resolution, FcCameraResolution.photo);
    expect(camera.calls, isNot(contains('startFrames')));
    expect(shutter, findsOneWidget);
  });

  final retake = find.text('Retake');
  final usePhoto = find.text('Use photo');

  group('review', () {
    testWidgets('the shutter shows the shot with Retake and Use photo', (
      tester,
    ) async {
      await pumpHost(tester);
      unawaited(open());
      await settle(tester);

      await tester.tap(shutter);
      await settle(tester);
      // Image decoding is real async work that fake time can't advance.
      await tester.runAsync(
        () => precacheImage(photoImage, navigatorKey.currentContext!),
      );
      await settle(tester);

      expect(find.byType(FcPhotoCameraPage), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(retake, findsOneWidget);
      expect(usePhoto, findsOneWidget);
      expect(shutter, findsNothing);
    });

    testWidgets('Use photo closes the camera with the shot', (tester) async {
      await pumpHost(tester);
      final result = open();
      await settle(tester);

      await tester.tap(shutter);
      await settle(tester);
      await tester.tap(usePhoto);
      await settle(tester);

      expect((await result)?.file.path, '/photo.jpg');
      expect(find.byType(FcPhotoCameraPage), findsNothing);
      expect(camera.calls.last, 'close');
    });

    testWidgets('Retake goes back to the live camera', (tester) async {
      await pumpHost(tester);
      final result = open();
      await settle(tester);

      await tester.tap(shutter);
      await settle(tester);
      await tester.tap(retake);
      await settle(tester);

      expect(shutter, findsOneWidget);
      expect(retake, findsNothing);

      await tester.tap(shutter);
      await settle(tester);
      await tester.tap(usePhoto);
      await settle(tester);
      expect(camera.calls.where((c) => c == 'takePicture'), hasLength(2));
      expect((await result)?.file.path, '/photo.jpg');
    });

    testWidgets('system back from a review retakes instead of leaving', (
      tester,
    ) async {
      await pumpHost(tester);
      unawaited(open());
      await settle(tester);

      await tester.tap(shutter);
      await settle(tester);
      await navigatorKey.currentState!.maybePop();
      await settle(tester);

      expect(find.byType(FcPhotoCameraPage), findsOneWidget);
      expect(shutter, findsOneWidget);
    });

    testWidgets('close from a review reports no photo', (tester) async {
      await pumpHost(tester);
      final result = open();
      await settle(tester);

      await tester.tap(shutter);
      await settle(tester);
      await tester.tap(find.byType(FcCloseButton));
      await settle(tester);

      expect(await result, isNull);
    });
  });

  testWidgets('close and system back from the live camera report no photo', (
    tester,
  ) async {
    await pumpHost(tester);
    var result = open();
    await settle(tester);
    await tester.tap(find.byType(FcCloseButton));
    await settle(tester);
    expect(await result, isNull);

    result = open();
    await settle(tester);
    await navigatorKey.currentState!.maybePop();
    await settle(tester);
    expect(await result, isNull);
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets('a second press while the photo is taken is ignored', (
    tester,
  ) async {
    camera.taking = Completer<void>();
    await pumpHost(tester);
    unawaited(open());
    await settle(tester);

    await tester.tap(shutter);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(shutter, warnIfMissed: false);
    await tester.pump();

    camera.taking!.complete();
    await settle(tester);
    expect(camera.calls.where((c) => c == 'takePicture'), hasLength(1));
    expect(usePhoto, findsOneWidget);
  });

  testWidgets('a failed photo says so and keeps the camera open', (
    tester,
  ) async {
    camera.takeError = const CameraException('busy');
    await pumpHost(tester);
    unawaited(open());
    await settle(tester);

    await tester.tap(shutter);
    await settle(tester);

    expect(find.text('Could not take the photo. Try again.'), findsOneWidget);
    expect(find.byType(FcPhotoCameraPage), findsOneWidget);
    expect(shutter, findsOneWidget);
  });

  testWidgets('the flash cycles auto, on, off', (tester) async {
    await pumpHost(tester);
    unawaited(open());
    await settle(tester);
    expect(camera.flash, FcFlashMode.auto);

    await tester.tap(find.byTooltip('Flash auto'));
    await settle(tester);
    expect(camera.flash, FcFlashMode.on);

    await tester.tap(find.byTooltip('Flash on'));
    await settle(tester);
    expect(camera.flash, FcFlashMode.off);
    expect(find.byTooltip('Flash off'), findsOneWidget);
  });

  testWidgets('a camera without a flash shows no flash button', (tester) async {
    camera.flashError = const CameraException('no flash unit');
    await pumpHost(tester);
    unawaited(open());
    await settle(tester);

    expect(find.byTooltip('Flash auto'), findsNothing);
    expect(shutter, findsOneWidget);
  });

  testWidgets('a pinch zooms the preview', (tester) async {
    camera.maxZoom = 8;
    await pumpHost(tester);
    unawaited(open());
    await settle(tester);

    final centre = tester.getCenter(find.byType(FcPhotoCameraPage));
    final left = await tester.startGesture(centre - const Offset(20, 0));
    final right = await tester.startGesture(centre + const Offset(20, 0));
    await left.moveBy(const Offset(-40, 0));
    await right.moveBy(const Offset(40, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await settle(tester);

    expect(camera.zoom, closeTo(3, 0.01));
  });

  testWidgets('switches to the front camera, which has no flash', (
    tester,
  ) async {
    camera.lenses = {FcCameraLens.front, FcCameraLens.back};
    await pumpHost(tester);
    unawaited(open());
    await settle(tester);

    await tester.tap(find.byTooltip('Switch camera'));
    await settle(tester);

    expect(camera.lens, FcCameraLens.front);
    expect(find.byTooltip('Flash auto'), findsNothing);
    expect(find.byTooltip('Switch camera'), findsOneWidget);
  });

  testWidgets('offers no switch on a device with one camera', (tester) async {
    await pumpHost(tester);
    unawaited(open());
    await settle(tester);

    expect(find.byTooltip('Switch camera'), findsNothing);
  });

  testWidgets('a device without a back camera opens the front one', (
    tester,
  ) async {
    camera.lenses = {FcCameraLens.front};
    await pumpHost(tester);
    unawaited(open());
    await settle(tester);

    expect(camera.lens, FcCameraLens.front);
    expect(shutter, findsOneWidget);
  });

  testWidgets('a camera that fails to open can be retried or left', (
    tester,
  ) async {
    camera.openError = const CameraException('in use');
    await pumpHost(tester);
    final result = open();
    await settle(tester);

    expect(find.text('Camera unavailable'), findsOneWidget);
    expect(shutter, findsNothing);

    camera.openError = null;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(camera.calls.where((c) => c == 'open'), hasLength(2));
    expect(shutter, findsOneWidget);

    await tester.tap(find.byType(FcCloseButton));
    await settle(tester);
    expect(await result, isNull);
  });

  testWidgets('the photo follows the screen orientation', (tester) async {
    await pumpHost(tester, size: const Size(780, 360));
    unawaited(open());
    await settle(tester);

    expect(camera.lockedLandscape, isTrue);
  });
}
