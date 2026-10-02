import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../config/fc_camera_kit.dart';
import '../error/fc_camera_exception.dart';
import 'compressor/fc_image_compressor.dart';
import 'fc_image_store.dart';
import 'metadata/fc_exif_writer.dart';
import 'metadata/fc_photo_metadata.dart';
import 'stamp/fc_stamp_renderer.dart';
import 'stamp/fc_stamp_style.dart';

/// One step of preparing an image, in the order they run.
enum FcImageStage {
  stamping('Adding the stamp'),
  compressing('Compressing'),
  writingMetadata('Writing metadata');

  const FcImageStage(this.label);

  final String label;

  /// The steps a run with these settings goes through, in order.
  static List<FcImageStage> planFor({
    required bool stamp,
    required bool writeMetadata,
  }) => [
    if (stamp) stamping,
    compressing,
    if (writeMetadata) FcImageStage.writingMetadata,
  ];
}

/// How to stamp an image; the same settings `capture()` uses.
final class FcStampSpec extends Equatable {
  const FcStampSpec({
    required this.placement,
    required this.dateFormat,
    this.includeDevice = false,
    this.style = const FcStampStyle(),
  });

  final StampPlacement placement;
  final String dateFormat;
  final bool includeDevice;
  final FcStampStyle style;

  @override
  List<Object?> get props => [placement, dateFormat, includeDevice, style];
}

/// A finished image file and what the pipeline learned producing it.
final class FcProcessedImage extends Equatable {
  const FcProcessedImage({
    required this.file,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.wasCompressed,
    required this.quality,
    required this.stamped,
  });

  final XFile file;
  final int sizeBytes;
  final int width;
  final int height;
  final bool wasCompressed;
  final int quality;
  final bool stamped;

  @override
  List<Object?> get props => [
    file.path,
    sizeBytes,
    width,
    height,
    wasCompressed,
    quality,
    stamped,
  ];
}

/// Stamp → compress → EXIF, shared by every feature that hands back a file.
///
/// Throws `FcCameraException`s; a file it saved is deleted if a later step
/// fails, so a failure never leaves anything behind.
abstract final class FcImagePipeline {
  static Future<FcProcessedImage> run(
    XFile source, {
    required int maxBytes,
    FcPhotoMetadata? metadata,
    bool writeMetadata = true,
    FcStampSpec? stamp,
    void Function(FcImageStage stage)? onStage,
  }) async {
    var bytes = await _read(source);
    final stamping = stamp != null && metadata != null;
    int width;
    int height;

    if (stamping) {
      onStage?.call(FcImageStage.stamping);
      final stamped = await FcStampRenderer.render(
        source: bytes,
        metadata: metadata,
        placement: stamp.placement,
        dateFormat: stamp.dateFormat,
        includeDevice: stamp.includeDevice,
        style: stamp.style,
      );
      (bytes, width, height) = (stamped.bytes, stamped.width, stamped.height);
    } else {
      (width, height) = await _dimensionsOf(bytes);
    }

    onStage?.call(FcImageStage.compressing);
    final outcome = await FcImageCompressor.toBudget(
      bytes: bytes,
      maxBytes: maxBytes,
      width: width,
      height: height,
    );

    final file = await FcImageStore.save(outcome.data);
    try {
      if (writeMetadata && metadata != null) {
        onStage?.call(FcImageStage.writingMetadata);
        // After compression: a JPEG re-encode drops EXIF.
        await FcExifWriter.write(file.path, metadata);
      }
    } catch (_) {
      await FcImageStore.deleteQuietly(file.path);
      rethrow;
    }

    return FcProcessedImage(
      file: XFile(file.path),
      sizeBytes: outcome.sizeBytes,
      width: outcome.width,
      height: outcome.height,
      wasCompressed: outcome.wasCompressed,
      quality: outcome.quality,
      stamped: stamping,
    );
  }

  static Future<Uint8List> _read(XFile source) async {
    try {
      return await source.readAsBytes();
    } catch (error, stackTrace) {
      throw StorageException(
        'Could not read the image.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Reads the header only; no full decode.
  static Future<(int, int)> _dimensionsOf(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (descriptor.width, descriptor.height);
    } catch (error, stackTrace) {
      throw ImageProcessingException(
        'The image is not readable.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
