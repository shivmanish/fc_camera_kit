import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermissions extends Mock implements FcPermissions {}

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late _MockPermissions permissions;

  setUp(() {
    permissions = _MockPermissions();
    when(() => permissions.isLocationServiceEnabled()).thenAnswer((_) async {
      return true;
    });
    when(() => permissions.statusOfAll(any())).thenAnswer((_) async {
      return {
        FcPermissionType.camera: FcPermissionStatus.denied,
        FcPermissionType.location: FcPermissionStatus.denied,
      };
    });
  });

  group('FcPermissionSheet', () {
    testWidgets('lists every required permission with its reason', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          FcPermissionSheet(
            required: FcPermissions.captureDefaults,
            permissions: permissions,
          ),
        ),
      );
      await tester.pump();

      expect(find.text(FcPermissionType.camera.label), findsOneWidget);
      expect(find.text(FcPermissionType.camera.reason), findsOneWidget);
      expect(find.text(FcPermissionType.location.label), findsOneWidget);
    });

    testWidgets('blocks the back gesture', (tester) async {
      await tester.pumpWidget(
        host(
          FcPermissionSheet(
            required: FcPermissions.captureDefaults,
            permissions: permissions,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) => w is PopScope && !w.canPop),
        findsOneWidget,
      );
    });

    testWidgets('offers Continue while denials are still retryable', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          FcPermissionSheet(
            required: FcPermissions.captureDefaults,
            permissions: permissions,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Open Settings'), findsNothing);
    });

    testWidgets('switches to Open Settings on a permanent denial', (
      tester,
    ) async {
      when(() => permissions.statusOfAll(any())).thenAnswer((_) async {
        return {
          FcPermissionType.camera: FcPermissionStatus.deniedForever,
          FcPermissionType.location: FcPermissionStatus.granted,
        };
      });

      await tester.pumpWidget(
        host(
          FcPermissionSheet(
            required: FcPermissions.captureDefaults,
            permissions: permissions,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Open Settings'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('marks a blocked permission distinctly from a denied one', (
      tester,
    ) async {
      when(() => permissions.statusOfAll(any())).thenAnswer((_) async {
        return {
          FcPermissionType.camera: FcPermissionStatus.deniedForever,
          FcPermissionType.location: FcPermissionStatus.denied,
        };
      });

      await tester.pumpWidget(
        host(
          FcPermissionSheet(
            required: FcPermissions.captureDefaults,
            permissions: permissions,
          ),
        ),
      );
      await tester.pump();

      // The blocked one swaps its reason line for an actionable hint; the
      // merely-denied one keeps its reason.
      expect(find.text('Blocked — enable in Settings'), findsOneWidget);
      expect(find.text(FcPermissionType.location.reason), findsOneWidget);
      expect(find.text(FcPermissionType.camera.reason), findsNothing);
    });

    testWidgets('survives a large text scale without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: FcPermissionSheet(
                required: FcPermissions.captureDefaults,
                permissions: permissions,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('offers a close button when cancelling is allowed', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          FcPermissionSheet(
            required: FcPermissions.captureDefaults,
            permissions: permissions,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FcCloseButton), findsOneWidget);
      expect(find.byType(FcSheetGrabber), findsOneWidget);
    });

    testWidgets('hides the close button when cancelling is disallowed', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          FcPermissionSheet(
            required: FcPermissions.captureDefaults,
            allowCancel: false,
            permissions: permissions,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(FcCloseButton), findsNothing);
      // The grabber stays: it marks the surface as a sheet regardless of
      // whether this particular one can be dismissed.
      expect(find.byType(FcSheetGrabber), findsOneWidget);
    });
  });

  group('FcLocationServiceDialog', () {
    setUp(() {
      when(() => permissions.statusOfAll(any())).thenAnswer((_) async {
        return {FcPermissionType.location: FcPermissionStatus.granted};
      });
      when(() => permissions.isLocationServiceEnabled()).thenAnswer((_) async {
        return false;
      });
    });

    testWidgets('explains the device toggle, not the permission', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(FcLocationServiceDialog(permissions: permissions)),
      );
      await tester.pump();

      expect(find.text('Turn on location'), findsOneWidget);
      expect(find.text('Open location settings'), findsOneWidget);
    });

    testWidgets('blocks the back gesture', (tester) async {
      await tester.pumpWidget(
        host(FcLocationServiceDialog(permissions: permissions)),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) => w is PopScope && !w.canPop),
        findsOneWidget,
      );
    });
  });
}
