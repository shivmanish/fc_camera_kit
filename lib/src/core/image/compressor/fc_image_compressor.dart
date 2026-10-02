import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../error/fc_camera_exception.dart';
import 'fc_compression_policy.dart';

/// Encodes to JPEG and brings the result under a byte budget.
///
/// Full resolution is preserved for as long as possible: quality is searched
/// down first, and the image is only scaled once the quality floor cannot
/// reach the budget on its own.
abstract final class FcImageCompressor {
  static Future<FcCompressionOutcome> toBudget({
    required Uint8List bytes,
    required int maxBytes,
    required int width,
    required int height,
    FcCompressionPolicy policy = const FcCompressionPolicy(),
  }) async {
    if (maxBytes <= 0) {
      throw const ImageProcessingException('maxBytes must be positive');
    }

    final steps = policy.qualitySteps;
    var currentWidth = width;
    var currentHeight = height;
    Uint8List? smallest;

    for (var round = 0; round <= policy.maxDownscaleRounds; round++) {
      // Highest quality first, stopping the moment one fits. Each attempt
      // ships the whole frame to the platform encoder, so the number of
      // attempts is the thing worth minimising.
      for (final quality in steps) {
        final encoded = await _encode(
          bytes,
          quality,
          currentWidth,
          currentHeight,
        );
        smallest = encoded;

        if (encoded.length <= maxBytes) {
          return FcCompressionOutcome(
            data: encoded,
            quality: quality,
            width: currentWidth,
            height: currentHeight,
            wasCompressed:
                quality != policy.startQuality || currentWidth != width,
          );
        }
      }

      // Quality alone could not reach the budget — give up some resolution.
      final shorter = currentWidth < currentHeight
          ? currentWidth
          : currentHeight;
      final next = policy.nextDimension(shorter);
      if (next == null) break;

      final scale = next / shorter;
      currentWidth = (currentWidth * scale).round();
      currentHeight = (currentHeight * scale).round();
    }

    throw SizeLimitException(
      'Could not bring the image under the size budget.',
      actualBytes: smallest?.length ?? bytes.length,
      limitBytes: maxBytes,
    );
  }

  static Future<Uint8List> _encode(
    Uint8List bytes,
    int quality,
    int width,
    int height,
  ) async {
    try {
      return await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        // These are *minimums*: passing the current size keeps full
        // resolution instead of the plugin's 1920x1080 default.
        minWidth: width,
        minHeight: height,
        // format defaults to jpeg and keepExif to false, which is what we
        // want: EXIF is written after compression, so carrying it here would
        // only preserve a stale orientation tag.
      );
    } catch (error, stackTrace) {
      throw ImageProcessingException(
        'JPEG encoding failed at quality $quality.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
