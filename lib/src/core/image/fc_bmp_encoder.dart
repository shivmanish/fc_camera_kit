import 'dart:typed_data';

/// Wraps raw RGBA pixels in a 32-bit BMP for the platform JPEG encoder.
///
/// Roughly 7x faster than PNG here, at the cost of about 2x frame memory.
abstract final class FcBmpEncoder {
  static const _headerSize = 54;

  static Uint8List encode(Uint8List rgba, int width, int height) {
    final expected = width * height * 4;
    if (rgba.length != expected) {
      throw ArgumentError(
        'Expected $expected bytes for ${width}x$height, got ${rgba.length}.',
      );
    }

    final out = Uint8List(_headerSize + expected);
    final header = ByteData.view(out.buffer);

    out[0] = 0x42; // 'B'
    out[1] = 0x4D; // 'M'
    header
      ..setUint32(2, out.length, Endian.little)
      ..setUint32(10, _headerSize, Endian.little)
      ..setUint32(14, 40, Endian.little)
      ..setInt32(18, width, Endian.little)
      // Positive height = bottom-up rows, matching the loop below.
      ..setInt32(22, height, Endian.little)
      ..setUint16(26, 1, Endian.little) // planes
      ..setUint16(28, 32, Endian.little) // bits per pixel
      ..setUint32(30, 0, Endian.little) // BI_RGB, uncompressed
      ..setUint32(34, expected, Endian.little)
      ..setUint32(38, 2835, Endian.little) // 72 dpi
      ..setUint32(42, 2835, Endian.little);

    // 32bpp rows need no padding; BMP stores pixels as BGRA.
    final stride = width * 4;
    for (var y = 0; y < height; y++) {
      var src = y * stride;
      var dst = _headerSize + (height - 1 - y) * stride;

      for (var x = 0; x < width; x++) {
        out[dst] = rgba[src + 2]; // B
        out[dst + 1] = rgba[src + 1]; // G
        out[dst + 2] = rgba[src]; // R
        out[dst + 3] = rgba[src + 3]; // A
        src += 4;
        dst += 4;
      }
    }

    return out;
  }
}
