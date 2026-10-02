import 'dart:typed_data';

/// Wraps raw RGBA pixels in a 32-bit BMP.
///
/// This is the handoff between the Flutter canvas and the platform's JPEG
/// encoder. That intermediate never touches disk and lives for milliseconds,
/// so it only has to be *decodable* — making it small is wasted work.
///
/// PNG spends roughly a second deflating a 12 MP frame that the next step
/// immediately inflates again. BMP is a 54-byte header plus a row copy, which
/// measured about 7x faster for an identical result.
///
/// The trade is peak memory: the source pixels and the BMP are both alive for
/// the duration of [encode], about 2x the frame in bytes — 92 MB for 12 MP.
/// That is why the compressor tries as few encodes as possible rather than
/// searching, and why this buffer is never held beyond the pipeline.
abstract final class FcBmpEncoder {
  static const _headerSize = 54;

  /// [rgba] must be `width * height * 4` bytes in RGBA order, as produced by
  /// `Image.toByteData(format: ImageByteFormat.rawRgba)`.
  static Uint8List encode(Uint8List rgba, int width, int height) {
    final expected = width * height * 4;
    if (rgba.length != expected) {
      throw ArgumentError(
        'Expected $expected bytes for ${width}x$height, got ${rgba.length}.',
      );
    }

    final out = Uint8List(_headerSize + expected);
    final header = ByteData.view(out.buffer);

    // BITMAPFILEHEADER
    out[0] = 0x42; // 'B'
    out[1] = 0x4D; // 'M'
    header
      ..setUint32(2, out.length, Endian.little)
      ..setUint32(10, _headerSize, Endian.little)
      // BITMAPINFOHEADER
      ..setUint32(14, 40, Endian.little)
      ..setInt32(18, width, Endian.little)
      // Positive height means bottom-up row order, which is what the rows are
      // written in below.
      ..setInt32(22, height, Endian.little)
      ..setUint16(26, 1, Endian.little) // planes
      ..setUint16(28, 32, Endian.little) // bits per pixel
      ..setUint32(30, 0, Endian.little) // BI_RGB, uncompressed
      ..setUint32(34, expected, Endian.little)
      ..setUint32(38, 2835, Endian.little) // 72 dpi
      ..setUint32(42, 2835, Endian.little);

    // 32bpp rows are already 4-byte aligned, so no padding is needed. Rows go
    // bottom to top, and each pixel is BGRA rather than RGBA.
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
