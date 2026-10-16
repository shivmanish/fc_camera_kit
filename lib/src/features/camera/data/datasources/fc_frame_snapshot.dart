import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/fc_camera_exception.dart';
import '../../../../core/image/fc_bmp_encoder.dart';
import '../../domain/entities/fc_camera_frame.dart';

/// Saves a frame as a photo; [FcFrameSnapshot.save] unless replaced.
typedef FcFrameSaver =
    Future<XFile> Function(FcCameraFrame frame, {required bool mirror});

/// Upright RGBA pixels of a camera frame.
typedef FcFramePixels = ({Uint8List rgba, int width, int height});

/// Turns an analysis frame into a photo file.
///
/// The photo is the very frame that was checked, so it can never miss what
/// the check saw, unlike a separate shutter that fires a moment later.
abstract final class FcFrameSnapshot {
  static int _sequence = 0;

  /// Converts off the UI isolate and writes a lossless BMP to the temp dir.
  ///
  /// [mirror] flips left–right, e.g. so a front-camera photo matches the
  /// mirrored preview the user framed it in.
  static Future<XFile> save(FcCameraFrame frame, {bool mirror = false}) async {
    try {
      final bytes = await Isolate.run(() {
        final pixels = toRgba(frame, mirror: mirror);
        return FcBmpEncoder.encode(pixels.rgba, pixels.width, pixels.height);
      });
      final directory = await getTemporaryDirectory();
      final file = File(
        p.join(
          directory.path,
          'fc_frame_${DateTime.now().millisecondsSinceEpoch}_${_sequence++}.bmp',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      return XFile(file.path);
    } catch (error, stackTrace) {
      throw ImageProcessingException(
        'Could not turn the camera frame into a photo.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Upright (rotated by the frame's rotation) and optionally mirrored RGBA.
  static FcFramePixels toRgba(FcCameraFrame frame, {bool mirror = false}) {
    final width = frame.uprightWidth;
    final height = frame.uprightHeight;
    final out = Uint8List(width * height * 4);
    final sourceWidth = frame.width;
    final sourceHeight = frame.height;
    final rotation = frame.rotationDegrees % 360;

    var o = 0;
    for (var y = 0; y < height; y++) {
      for (var x0 = 0; x0 < width; x0++) {
        final x = mirror ? width - 1 - x0 : x0;
        // Where this upright pixel comes from in the sensor frame, for a
        // clockwise rotation of the source by [rotation].
        final (sx, sy) = switch (rotation) {
          90 => (y, sourceHeight - 1 - x),
          180 => (sourceWidth - 1 - x, sourceHeight - 1 - y),
          270 => (sourceWidth - 1 - y, x),
          _ => (x, y),
        };
        _pixel(frame, sx, sy, out, o);
        o += 4;
      }
    }
    return (rgba: out, width: width, height: height);
  }

  static void _pixel(FcCameraFrame frame, int x, int y, Uint8List out, int o) {
    final bytes = frame.bytes;
    final stride = frame.bytesPerRow;
    switch (frame.format) {
      case FcFrameFormat.bgra8888:
        final i = y * stride + x * 4;
        out[o] = bytes[i + 2];
        out[o + 1] = bytes[i + 1];
        out[o + 2] = bytes[i];
      case FcFrameFormat.nv21:
        // Full Y plane, then interleaved V/U at half resolution.
        final luma = bytes[y * stride + x];
        final uv = stride * frame.height + (y >> 1) * stride + (x & ~1);
        final v = bytes[uv] - 128;
        final u = bytes[uv + 1] - 128;
        // JFIF full-range YUV → RGB, in 16.16 fixed point.
        out[o] = _clamp(luma + ((91881 * v) >> 16));
        out[o + 1] = _clamp(luma - ((22554 * u + 46802 * v) >> 16));
        out[o + 2] = _clamp(luma + ((116130 * u) >> 16));
    }
    out[o + 3] = 255;
  }

  static int _clamp(int value) => value < 0 ? 0 : (value > 255 ? 255 : value);
}
