import 'dart:typed_data';

enum FcFrameFormat { nv21, bgra8888 }

enum FcCameraLens { front, back }

enum FcCameraResolution {
  /// 720p, cheap enough to analyse every frame.
  analysis,

  /// 1080p, so low-memory phones can still stamp and compress it.
  photo,
}

enum FcFlashMode { auto, on, off }

/// Not Equatable: holds megabytes of pixels and is never compared.
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

  /// Before rotation.
  final int width;
  final int height;
  final int bytesPerRow;

  /// Clockwise: 0, 90, 180 or 270.
  final int rotationDegrees;
  final FcFrameFormat format;

  bool get _sideways => rotationDegrees % 180 != 0;

  int get uprightWidth => _sideways ? height : width;
  int get uprightHeight => _sideways ? width : height;

  /// Sparse sample, cheap enough to run per frame.
  double sampleLuminance({int stride = 64}) {
    var sum = 0;
    var count = 0;
    switch (format) {
      case FcFrameFormat.nv21:
        // First width * height bytes are the Y plane.
        final end = (width * height).clamp(0, bytes.length);
        for (var i = 0; i < end; i += stride) {
          sum += bytes[i];
          count++;
        }
      case FcFrameFormat.bgra8888:
        for (var i = 0; i + 2 < bytes.length; i += stride * 4) {
          // Integer Rec. 601 luma.
          sum += (29 * bytes[i] + 150 * bytes[i + 1] + 77 * bytes[i + 2]) >> 8;
          count++;
        }
    }
    return count == 0 ? 0 : sum / count;
  }
}
