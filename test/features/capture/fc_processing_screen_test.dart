import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:fc_camera_kit/src/core/navigation/fc_navigator.dart';
import 'package:fc_camera_kit/src/features/camera/domain/entities/fc_camera_frame.dart';
import 'package:fc_camera_kit/src/features/camera/presentation/pages/fc_photo_camera_page.dart';
import 'package:fc_camera_kit/src/features/camera/presentation/widgets/fc_camera_shutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_live_camera.dart';
import '../../helpers/fc_test_app.dart';

/// Counts picks and returns nothing, as a cancelled gallery does.
final class _FakeImageSource extends FcImageSource {
  var picks = 0;

  @override
  Future<XFile?> pick() async {
    picks++;
    return null;
  }
}

void main() {
  late FakeLiveCamera camera;
  late GlobalKey<NavigatorState> navigatorKey;

  setUp(() async {
    FcCameraKit.reset();
    await FcCameraKit.instance.init(app: fcTestApp);
    camera = FakeLiveCamera()..lenses = {FcCameraLens.back};
    navigatorKey = GlobalKey<NavigatorState>();
  });

  tearDown(FcCameraKit.reset);

  Future<void> pumpHost(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(360, 780) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('host')),
      ),
    );
  }

  Future<Object?> process(
    FcCaptureSource source, {
    FcImageSource? imageSource,
  }) => FcNavigator.push<Object>(
    navigatorKey.currentContext!,
    (_) => FcProcessingScreen(
      source: source,
      imageSource: imageSource,
      liveCamera: camera,
    ),
  );

  // Spinners never settle; pump fixed steps instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the camera is always the in-app one', (tester) async {
    final gallery = _FakeImageSource();
    await pumpHost(tester);
    final outcome = process(FcCaptureSource.camera, imageSource: gallery);
    await settle(tester);

    expect(find.byType(FcPhotoCameraPage), findsOneWidget);
    expect(camera.calls, contains('open'));
    expect(gallery.picks, 0);

    // Leaving the camera cancels the capture.
    await tester.tap(find.byType(FcCloseButton));
    await settle(tester);
    expect(await outcome, const CancelledFailure());
    expect(find.byType(FcProcessingScreen), findsNothing);
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets('a used photo moves on to processing', (tester) async {
    await pumpHost(tester);
    unawaited(process(FcCaptureSource.camera));
    await settle(tester);

    await tester.tap(find.byType(FcCameraShutter));
    await settle(tester);
    await tester.tap(find.text('Use photo'));
    await tester.pump();
    await tester.pump();

    // Stamping needs a real file and native compressor; stop at the hand-off.
    expect(camera.calls, contains('takePicture'));
    expect(find.byType(FcPhotoCameraPage), findsNothing);
    expect(find.byType(FcProcessingScreen), findsOneWidget);
    expect(find.text('Keep the app open'), findsOneWidget);
  });

  testWidgets('the gallery uses the picker, never the camera', (tester) async {
    final gallery = _FakeImageSource();
    await pumpHost(tester);
    final outcome = process(FcCaptureSource.gallery, imageSource: gallery);
    await settle(tester);

    expect(gallery.picks, 1);
    expect(camera.calls, isEmpty);
    expect(await outcome, const CancelledFailure());
  });
}
