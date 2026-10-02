import 'dart:ui';

import 'package:fc_camera_kit/src/features/camera/domain/entities/fc_face_frame_geometry.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const phone = Size(390, 844);
  const tablet = Size(820, 1180);
  const landscape = Size(844, 390);
  const sensor = 4 / 3;

  group('ovalFor', () {
    for (final (name, size) in [
      ('phone', phone),
      ('tablet', tablet),
      ('landscape', landscape),
      ('short phone', const Size(360, 640)),
    ]) {
      test('$name: a face-shaped oval that fits the screen', () {
        final oval = FcFaceFrameGeometry.ovalFor(size);

        expect(
          oval.height / oval.width,
          closeTo(FcFaceFrameGeometry.faceAspect, 0.001),
        );
        expect((Offset.zero & size).contains(oval.topLeft), isTrue);
        expect((Offset.zero & size).contains(oval.bottomRight), isTrue);
      });
    }

    test('portrait leaves room below for the hint and shutter', () {
      final oval = FcFaceFrameGeometry.ovalFor(const Size(360, 640));
      expect(oval.height, lessThanOrEqualTo(640 * 0.58 + 1e-6));
      expect(640 - oval.bottom, greaterThan(180));
    });

    test('a tablet does not get a screen-filling oval', () {
      final oval = FcFaceFrameGeometry.ovalFor(tablet);
      expect(oval.height, lessThanOrEqualTo(tablet.height * 0.58 + 1e-6));
    });

    test('landscape puts the oval left, leaving the right for controls', () {
      final oval = FcFaceFrameGeometry.ovalFor(landscape);
      expect(oval.center.dx, lessThan(landscape.width / 2));
      expect(landscape.width - oval.right, greaterThan(300));
    });
  });

  group('ovalInFrame', () {
    test('a portrait phone matches the rules default target', () {
      final oval = FcFaceFrameGeometry.ovalInFrame(
        phone,
        FcFaceFrameGeometry.uprightAspect(sensor, landscape: false),
      );
      const target = FcFaceRules.defaultTarget;

      expect(oval.left, closeTo(target.left, 0.01));
      expect(oval.top, closeTo(target.top, 0.01));
      expect(oval.width, closeTo(target.width, 0.01));
      expect(oval.height, closeTo(target.height, 0.01));
    });

    test('stays inside the frame on every screen', () {
      for (final size in [phone, tablet, landscape]) {
        final oval = FcFaceFrameGeometry.ovalInFrame(
          size,
          FcFaceFrameGeometry.uprightAspect(
            sensor,
            landscape: size.width > size.height,
          ),
        );
        expect(oval.left, greaterThanOrEqualTo(0), reason: '$size');
        expect(oval.top, greaterThanOrEqualTo(0), reason: '$size');
        expect(oval.right, lessThanOrEqualTo(1), reason: '$size');
        expect(oval.bottom, lessThanOrEqualTo(1), reason: '$size');
      }
    });

    test('the front camera mirrors left and right', () {
      const aspect = sensor;
      final mirrored = FcFaceFrameGeometry.ovalInFrame(landscape, aspect);
      final plain = FcFaceFrameGeometry.ovalInFrame(
        landscape,
        aspect,
        mirrored: false,
      );

      expect(mirrored.left, closeTo(1 - plain.right, 1e-9));
      expect(mirrored.right, closeTo(1 - plain.left, 1e-9));
    });

    test('the upright ratio flips with orientation', () {
      expect(
        FcFaceFrameGeometry.uprightAspect(sensor, landscape: false),
        closeTo(0.75, 1e-9),
      );
      expect(
        FcFaceFrameGeometry.uprightAspect(sensor, landscape: true),
        closeTo(sensor, 1e-9),
      );
    });
  });
}
