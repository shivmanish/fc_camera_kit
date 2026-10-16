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

enum FcImageStage {
  stamping('Adding the stamp'),
  compressing('Compressing'),
  writingMetadata('Writing metadata');

  const FcImageStage(this.label);

  final String label;

  static List<FcImageStage> planFor({
    required bool stamp,
    required bool writeMetadata,
  }) => [
    if (stamp) stamping,
    compressing,
    if (writeMetadata) FcImageStage.writingMetadata,
  ];
}

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

final class FcProcessedImage extends Equatable {
  const FcProcessedImage({
    required this.file,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.wasCompressed,
    required this.quality,
    required this.stamped,
    this.metadata,
  });

  final XFile file;
  final int sizeBytes;
  final int width;
  final int height;
  final bool wasCompressed;
  final int quality;
  final bool stamped;

  /// Carries this file's own `imageId` once EXIF is written.
  final FcPhotoMetadata? metadata;

  @override
  List<Object?> get props => [
    file.path,
    sizeBytes,
    width,
    height,
    wasCompressed,
    quality,
    stamped,
    metadata,
  ];
}

/// Stamps, compresses and tags an image; cleans up its file on failure.
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
      // Reserve EXIF space so the final file still fits the limit.
      maxBytes: writeMetadata && metadata != null
          ? maxBytes - FcExifWriter.reservedBytes
          : maxBytes,
      width: width,
      height: height,
    );

    final file = await FcImageStore.save(outcome.data);
    var embedded = metadata;
    try {
      if (writeMetadata && metadata != null) {
        onStage?.call(FcImageStage.writingMetadata);
        // Must follow compression; re-encoding a JPEG drops EXIF.
        embedded = await FcExifWriter.write(file.path, metadata);
      }
    } catch (_) {
      await FcImageStore.deleteQuietly(file.path);
      rethrow;
    }

    return FcProcessedImage(
      file: XFile(file.path),
      sizeBytes: await file.length(),
      width: outcome.width,
      height: outcome.height,
      wasCompressed: outcome.wasCompressed,
      quality: outcome.quality,
      stamped: stamping,
      metadata: embedded,
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

  // Header only; avoids a full decode.
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
