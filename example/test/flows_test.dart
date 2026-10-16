import 'package:share_plus/share_plus.dart' show XFile;
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:fc_camera_kit_example/src/home/home_cubit.dart';
import 'package:fc_camera_kit_example/src/home/widgets/action_bar.dart';
import 'package:fc_camera_kit_example/src/home/widgets/face_card.dart';
import 'package:fc_camera_kit_example/src/home/widgets/scan_card.dart';
import 'package:fc_camera_kit_example/src/home/widgets/stamp_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FcFaceResult selfie(String path) => FcFaceResult(
    file: XFile(path),
    width: 720,
    height: 960,
    sizeBytes: 90000,
    capturedAt: DateTime(2026, 10, 2),
    livenessPassed: true,
    face: const FcFaceBox(left: 0.3, top: 0.2, width: 0.4, height: 0.5),
    pose: const FcHeadPose(),
    stamped: false,
  );

  Widget host(HomeCubit cubit, Widget child) => BlocProvider.value(
    value: cubit,
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  group('ActionBar', () {
    testWidgets('offers all three flows, one tap each', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: ActionBar(
              enabled: true,
              onCapture: () => tapped.add('photo'),
              onScan: () => tapped.add('scan'),
              onFace: () => tapped.add('face'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Photo'));
      await tester.tap(find.text('Scan'));
      await tester.tap(find.text('Face'));

      expect(tapped, ['photo', 'scan', 'face']);
    });

    testWidgets('disables every action while a flow runs', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: ActionBar(
              enabled: false,
              onCapture: () => tapped++,
              onScan: () => tapped++,
              onFace: () => tapped++,
            ),
          ),
        ),
      );

      for (final label in ['Photo', 'Scan', 'Face']) {
        await tester.tap(find.text(label), warnIfMissed: false);
      }
      expect(tapped, 0);
    });

    testWidgets('fits a 320 dp phone without overflow', (tester) async {
      tester.view
        ..physicalSize = const Size(960, 1704)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: ActionBar(
              enabled: true,
              onCapture: () {},
              onScan: () {},
              onFace: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('FaceCard', () {
    testWidgets('shows nothing until a face scan succeeds', (tester) async {
      final cubit = HomeCubit();
      addTearDown(cubit.close);

      await tester.pumpWidget(host(cubit, const FaceCard()));

      expect(find.text('FACE SCANS'), findsNothing);
    });

    testWidgets('shows each selfie, newest first, like the other rows', (
      tester,
    ) async {
      final cubit = HomeCubit()
        ..faceScanFinished(fcSuccess(selfie('/a.jpg')))
        ..faceScanFinished(fcSuccess(selfie('/b.jpg')));
      addTearDown(cubit.close);

      await tester.pumpWidget(host(cubit, const FaceCard()));

      expect(find.text('FACE SCANS'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(cubit.state.faces.map((face) => face.file.path), [
        '/b.jpg',
        '/a.jpg',
      ]);
    });

    testWidgets('tapping a selfie opens it in the viewer', (tester) async {
      final cubit = HomeCubit()..faceScanFinished(fcSuccess(selfie('/a.jpg')));
      addTearDown(cubit.close);

      await tester.pumpWidget(host(cubit, const FaceCard()));
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.byType(StampViewer), findsOneWidget);
      expect(find.text('Face scan'), findsOneWidget);
    });

    testWidgets('a cancelled face scan adds nothing and shows no error', (
      tester,
    ) async {
      final cubit = HomeCubit()
        ..faceScanFinished(fcFailure(const CancelledFailure()));
      addTearDown(cubit.close);

      await tester.pumpWidget(host(cubit, const FaceCard()));

      expect(find.text('FACE SCANS'), findsNothing);
      expect(cubit.state.captureError, isNull);
      expect(cubit.state.capturing, isFalse);
    });

    testWidgets('a failed face scan is surfaced as an error', (tester) async {
      final cubit = HomeCubit()
        ..faceScanFinished(fcFailure(const CameraFailure('busy')));
      addTearDown(cubit.close);

      expect(cubit.state.captureError, const CameraFailure('busy'));
      expect(cubit.state.capturing, isFalse);
    });
  });

  group('ScanCard', () {
    testWidgets('renders scanned pages the same way', (tester) async {
      final cubit = HomeCubit()
        ..scanFinished(
          fcSuccess(
            FcScanResult([
              FcScannedPage(
                file: XFile('/page.jpg'),
                sizeBytes: 1,
                width: 1,
                height: 1,
                wasCompressed: false,
                quality: 90,
              ),
            ]),
          ),
        );
      addTearDown(cubit.close);

      await tester.pumpWidget(host(cubit, const ScanCard()));

      expect(find.text('SCANNED DOCUMENTS'), findsOneWidget);
    });
  });
}
