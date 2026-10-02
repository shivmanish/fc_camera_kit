import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:fc_camera_kit_example/src/home/widgets/capture_card.dart';
import 'package:fc_camera_kit_example/src/home/widgets/metadata_card.dart';
import 'package:fc_camera_kit_example/src/home/widgets/section_card.dart';
import 'package:fc_camera_kit_example/src/home/widgets/stamp_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(FcCameraKit.reset);

  group('SectionCard', () {
    testWidgets('upper-cases its label and renders its child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionCard(label: 'Access', child: Text('body')),
          ),
        ),
      );

      expect(find.text('ACCESS'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });
  });

  group('kit wiring', () {
    test('init seeds the user the demo stamps', () async {
      await FcCameraKit.instance.init(
        user: (id: 'EMP-2291', name: 'Asha Verma'),
        placement: StampPlacement.extend,
        requireLocation: true,
      );

      expect(FcCameraKit.instance.user?.name, 'Asha Verma');
      expect(FcCameraKit.instance.placement, StampPlacement.extend);
      expect(FcCameraKit.instance.requireLocation, isTrue);
    });

    test(
      'buildMetadata carries the seeded user into the stamp preview',
      () async {
        await FcCameraKit.instance.init(user: (id: 'EMP-1', name: 'Asha'));

        final meta = FcCameraKit.instance.buildMetadata(
          location: const FcGeoLocation(
            latitude: 18.52043,
            longitude: 73.856743,
          ),
        );

        expect(meta.hasUser, isTrue);
        expect(meta.hasLocation, isTrue);
        expect(meta.location?.coordinates, '18.520430, 73.856743');
      },
    );
  });

  group('CaptureCard', () {
    testWidgets('renders nothing until a capture exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );

      expect(find.byType(CaptureCard), findsNothing);
    });
  });

  group('StampViewer', () {
    testWidgets('shows the photo full screen with zoom', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: StampViewer(path: '/tmp/none.jpg')),
      );
      await tester.pump();

      expect(find.text('Stamped photo'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });

  group('MetadataCard', () {
    testWidgets('renders nothing before metadata exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );

      expect(find.byType(MetadataCard), findsNothing);
    });
  });
}
