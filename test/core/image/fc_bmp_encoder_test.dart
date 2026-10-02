import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List solid(int w, int h, int r, int g, int b) {
    final bytes = Uint8List(w * h * 4);
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = r;
      bytes[i + 1] = g;
      bytes[i + 2] = b;
      bytes[i + 3] = 0xFF;
    }
    return bytes;
  }

  group('FcBmpEncoder', () {
    test('writes a well-formed header', () {
      final bmp = FcBmpEncoder.encode(solid(2, 2, 10, 20, 30), 2, 2);
      final view = ByteData.view(bmp.buffer);

      expect(bmp[0], 0x42, reason: 'B');
      expect(bmp[1], 0x4D, reason: 'M');
      expect(view.getUint32(2, Endian.little), bmp.length);
      expect(view.getUint32(10, Endian.little), 54, reason: 'pixel offset');
      expect(view.getInt32(18, Endian.little), 2, reason: 'width');
      expect(view.getInt32(22, Endian.little), 2, reason: 'height');
      expect(view.getUint16(28, Endian.little), 32, reason: 'bits per pixel');
      expect(view.getUint32(30, Endian.little), 0, reason: 'uncompressed');
    });

    test('is exactly header plus pixels — no compression, no padding', () {
      final bmp = FcBmpEncoder.encode(solid(64, 32, 1, 2, 3), 64, 32);

      expect(bmp.length, 54 + 64 * 32 * 4);
    });

    test('rejects a buffer that does not match the dimensions', () {
      expect(
        () => FcBmpEncoder.encode(Uint8List(8), 10, 10),
        throwsArgumentError,
      );
    });

    test(
      'decodes back to the same image, with channels in the right order',
      () async {
        const w = 4, h = 3;
        final bmp = FcBmpEncoder.encode(solid(w, h, 200, 100, 50), w, h);

        // The real proof: a platform decoder reads it. If Skia accepts this,
        // BitmapFactory and ImageIO will too.
        final codec = await ui.instantiateImageCodec(bmp);
        final frame = await codec.getNextFrame();
        final pixels = await frame.image.toByteData();

        expect(frame.image.width, w);
        expect(frame.image.height, h);
        // Red, green, blue survive in that order — a BGRA swap bug shows here.
        expect(pixels!.getUint8(0), 200);
        expect(pixels.getUint8(1), 100);
        expect(pixels.getUint8(2), 50);

        frame.image.dispose();
        codec.dispose();
      },
    );

    test('preserves row order — top row stays on top', () async {
      const w = 2, h = 2;
      final rgba = Uint8List.fromList([
        // top row: red, red
        255, 0, 0, 255, 255, 0, 0, 255,
        // bottom row: blue, blue
        0, 0, 255, 255, 0, 0, 255, 255,
      ]);

      final codec = await ui.instantiateImageCodec(
        FcBmpEncoder.encode(rgba, w, h),
      );
      final frame = await codec.getNextFrame();
      final pixels = (await frame.image.toByteData())!;

      // BMP stores rows bottom-up; getting this wrong flips the stamp.
      expect(pixels.getUint8(0), 255, reason: 'top-left red');
      expect(pixels.getUint8(2), 0, reason: 'top-left not blue');

      frame.image.dispose();
      codec.dispose();
    });
  });
}
