import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// A solid PNG to stamp, built through the same canvas path the renderer uses.
Future<Uint8List> solidImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, width * 1.0, height * 1.0),
  ).drawRect(
    ui.Rect.fromLTWH(0, 0, width * 1.0, height * 1.0),
    ui.Paint()..color = const ui.Color(0xFF3366AA),
  );

  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<({int width, int height})> sizeOf(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final size = (width: frame.image.width, height: frame.image.height);
  frame.image.dispose();
  codec.dispose();
  return size;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final capturedAt = DateTime(2026, 9, 17, 14, 5);
  const pune = FcGeoLocation(
    latitude: 18.520430,
    longitude: 73.856743,
    address: 'Shivajinagar, Pune',
  );
  const dateFormat = 'dd MMM yyyy, hh:mm a';

  group('buildLines', () {
    test('renders address and coordinates together', () {
      final lines = FcStampRenderer.buildLines(
        FcPhotoMetadata(capturedAt: capturedAt, location: pune),
        dateFormat,
      );

      expect(lines.last, 'Shivajinagar, Pune  ·  (18.520430, 73.856743)');
    });

    test('falls back to bare coordinates with no address', () {
      final lines = FcStampRenderer.buildLines(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          location: const FcGeoLocation(latitude: 1.5, longitude: 2.5),
        ),
        dateFormat,
      );

      expect(lines.last, '(1.500000, 2.500000)');
    });

    test('drops the location line entirely when there is no fix', () {
      final lines = FcStampRenderer.buildLines(
        FcPhotoMetadata(capturedAt: capturedAt, userName: 'Asha'),
        dateFormat,
      );

      expect(lines, hasLength(2));
      expect(lines.any((l) => l.contains('(')), isFalse);
    });

    test('puts identity first so it reads as the headline', () {
      final lines = FcStampRenderer.buildLines(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          userName: 'Asha Verma',
          userId: 'EMP-2291',
        ),
        dateFormat,
      );

      expect(lines.first, 'Asha Verma  ·  EMP-2291');
    });

    test('omits the device unless the config asks for it', () {
      final meta = FcPhotoMetadata(
        capturedAt: capturedAt,
        deviceModel: 'Google Pixel 8',
      );

      expect(
        FcStampRenderer.buildLines(meta, dateFormat),
        isNot(contains('Google Pixel 8')),
      );
      expect(
        FcStampRenderer.buildLines(meta, dateFormat, includeDevice: true),
        contains('Google Pixel 8'),
      );
    });

    test('always includes the timestamp, even with nothing else', () {
      final lines = FcStampRenderer.buildLines(
        FcPhotoMetadata(capturedAt: capturedAt),
        dateFormat,
      );

      expect(lines, hasLength(1));
      expect(lines.single, '17 Sep 2026, 02:05 PM');
    });
  });

  group('render', () {
    test('overlay preserves the original dimensions', () async {
      final source = await solidImage(800, 600);

      final stamped = await FcStampRenderer.render(
        source: source,
        metadata: FcPhotoMetadata(capturedAt: capturedAt, location: pune),
        placement: StampPlacement.overlay,
        dateFormat: dateFormat,
      );

      expect(
        (width: stamped.width, height: stamped.height),
        (width: 800, height: 600),
      );
    });

    test('extend grows the canvas below the photo', () async {
      final source = await solidImage(800, 600);

      final stamped = await FcStampRenderer.render(
        source: source,
        metadata: FcPhotoMetadata(capturedAt: capturedAt, location: pune),
        placement: StampPlacement.extend,
        dateFormat: dateFormat,
      );

      expect(stamped.width, 800);
      expect(
        stamped.height,
        greaterThan(600),
        reason: 'extend must add a panel, not cover the photo',
      );
    });

    test('actually changes the pixels', () async {
      final source = await solidImage(800, 600);

      final stamped = await FcStampRenderer.render(
        source: source,
        metadata: FcPhotoMetadata(capturedAt: capturedAt, location: pune),
        placement: StampPlacement.overlay,
        dateFormat: dateFormat,
      );

      expect(stamped.bytes, isNot(equals(source)));
    });

    test('overlay never widens the image, whatever the text', () async {
      final source = await solidImage(800, 600);

      final stamped = await FcStampRenderer.render(
        source: source,
        metadata: FcPhotoMetadata(
          capturedAt: capturedAt,
          userName: 'A very long name that would otherwise band the frame',
          userId: 'EMP-0000000001',
          location: pune,
        ),
        placement: StampPlacement.overlay,
        dateFormat: dateFormat,
      );

      // The strip is capped at half the width, so long text wraps inside it
      // rather than stretching the canvas.
      expect(
        (width: stamped.width, height: stamped.height),
        (width: 800, height: 600),
      );
    });

    test('rejects bytes that are not an image', () async {
      await expectLater(
        FcStampRenderer.render(
          source: Uint8List.fromList([1, 2, 3, 4]),
          metadata: FcPhotoMetadata(capturedAt: capturedAt),
          placement: StampPlacement.overlay,
          dateFormat: dateFormat,
        ),
        throwsA(isA<ImageProcessingException>()),
      );
    });
  });

  group('FcStampStyle', () {
    const style = FcStampStyle();

    test('solves the font so the badge fills the target width', () {
      const lines = ['Asha Verma  ·  EMP-2291'];

      final fontSize = FcStampRenderer.fitFontSize(lines, style, 400);
      final padding = style.paddingFor(fontSize);
      final painter = TextPainter(
        text: TextSpan(
          text: lines.single,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      expect(painter.width + padding * 2, closeTo(400, 1));
    });

    test('a wider target yields a larger font', () {
      const lines = ['Asha Verma  ·  EMP-2291'];

      expect(
        FcStampRenderer.fitFontSize(lines, style, 800),
        greaterThan(FcStampRenderer.fitFontSize(lines, style, 400)),
      );
    });

    test('the longest line drives the fit, not the first', () {
      final short = FcStampRenderer.fitFontSize(['Asha'], style, 400);
      final long = FcStampRenderer.fitFontSize(
        ['Asha', 'a considerably longer second line that must fit too'],
        style,
        400,
      );

      expect(long, lessThan(short));
    });

    test('clamps rather than producing an absurd size', () {
      expect(
        FcStampRenderer.fitFontSize(['.'], style, 99999),
        style.maxFontSize,
      );
      expect(FcStampRenderer.fitFontSize([], style, 400), style.minFontSize);
    });

    test('padding is a multiple of the solved size, not the image', () {
      expect(style.paddingFor(20), 20 * style.paddingRatio);
      expect(style.paddingFor(40), 40 * style.paddingRatio);
    });

    test('extend pads evenly on all four sides', () {
      final insets = style.insetsFor(StampPlacement.extend, 20);

      expect(insets.top, insets.bottom);
      expect(insets.top, insets.horizontal);
    });

    test('overlay has no vertical inset at all', () {
      final insets = style.insetsFor(StampPlacement.overlay, 20);

      expect(insets.top, 0);
      expect(insets.bottom, 0);
      expect(
        insets.horizontal,
        greaterThan(0),
        reason: 'text still needs breathing room from the frame edge',
      );
    });

    test('overlay covers strictly less photo than extend pads', () {
      final overlay = style.insetsFor(StampPlacement.overlay, 20);
      final extend = style.insetsFor(StampPlacement.extend, 20);

      expect(
        overlay.top + overlay.bottom,
        lessThan(extend.top + extend.bottom),
      );
    });

    test('horizontal inset is the same either way', () {
      expect(
        style.insetsFor(StampPlacement.overlay, 20).horizontal,
        style.insetsFor(StampPlacement.extend, 20).horizontal,
      );
    });

    test('insets scale with the solved font size', () {
      expect(
        style.insetsFor(StampPlacement.extend, 40).top,
        greaterThan(style.insetsFor(StampPlacement.extend, 10).top),
      );
    });

    test('the scrim stays light enough to see the photo through', () {
      expect(
        style.scrimColor.a,
        lessThan(0.3),
        reason: 'a heavy scrim defeats the point of blurring the backdrop',
      );
    });
  });
}
