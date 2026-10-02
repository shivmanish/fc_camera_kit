import 'dart:typed_data';

/// Pixel layouts the live camera delivers; both are read by ML Kit as is.
enum FcFrameFormat { nv21, bgra8888 }

/// Which camera on the device.
enum FcCameraLens { front, back }

/// One analysis frame from the live camera, free of any plugin type.
///
/// Not Equatable on purpose: it carries a megabyte of pixels and is never
/// compared, only handed on.
final class FcCameraFrame {
  const FcCameraFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.rotationDegrees,
    required this.format,
  });

  final Uint8List bytes;

  /// Sensor size, before rotation.
  final int width;
  final int height;
  final int bytesPerRow;

  /// Clockwise rotation that makes the frame upright: 0, 90, 180 or 270.
  final int rotationDegrees;
  final FcFrameFormat format;

  bool get _sideways => rotationDegrees % 180 != 0;

  int get uprightWidth => _sideways ? height : width;
  int get uprightHeight => _sideways ? width : height;

  /// Mean brightness 0–255 from a sparse sample, cheap enough per frame.
  double sampleLuminance({int stride = 64}) {
    var sum = 0;
    var count = 0;
    switch (format) {
      case FcFrameFormat.nv21:
        // The first width × height bytes are the Y (luma) plane.
        final end = (width * height).clamp(0, bytes.length);
        for (var i = 0; i < end; i += stride) {
          sum += bytes[i];
          count++;
        }
      case FcFrameFormat.bgra8888:
        for (var i = 0; i + 2 < bytes.length; i += stride * 4) {
          // Rec. 601 luma, in integers: (29 B + 150 G + 77 R) / 256.
          sum += (29 * bytes[i] + 150 * bytes[i + 1] + 77 * bytes[i + 2]) >> 8;
          count++;
        }
    }
    return count == 0 ? 0 : sum / count;
  }
}
