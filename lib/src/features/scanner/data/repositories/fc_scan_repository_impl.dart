import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';

import '../../../../core/config/fc_scan_options.dart';
import '../../../../core/error/fc_camera_exception.dart';
import '../../../../core/error/fc_camera_failure.dart';
import '../../../../core/error/fc_exception_mapper.dart';
import '../../../../core/image/compressor/fc_image_compressor.dart';
import '../../../../core/image/fc_image_store.dart';
import '../../../../core/image/metadata/fc_exif_writer.dart';
import '../../../../core/image/metadata/fc_photo_metadata.dart';
import '../../../../core/utils/fc_result.dart';
import '../../../stamping/fc_stamp_renderer.dart';
import '../../domain/entities/fc_scan_result.dart';
import '../../domain/entities/fc_scan_stage.dart';
import '../../domain/entities/fc_scan_stamp.dart';
import '../../domain/repositories/fc_scan_repository.dart';
import '../datasources/fc_native_scan_engine.dart';
import '../datasources/fc_scan_engine.dart';

final class FcScanRepositoryImpl implements FcScanRepository {
  FcScanRepositoryImpl({FcScanEngine? engine})
    : _engine = engine ?? FcNativeScanEngine();

  final FcScanEngine _engine;

  @override
  Future<FcResult<List<XFile>>> acquire(FcScanOptions options) async {
    try {
      final paths = await _engine.scan(options);
      if (paths == null || paths.isEmpty) {
        return fcFailure(const CancelledFailure());
      }
      return fcSuccess([for (final path in paths) XFile(path)]);
    } on FcCameraException catch (error) {
      return fcFailure(error.toFailure(permission: 'camera'));
    } catch (error) {
      return fcFailure(UnknownFailure('Scanner failed: $error'));
    }
  }

  @override
  Future<FcResult<FcScannedPage>> process(
    XFile raw, {
    required int maxBytes,
    FcPhotoMetadata? metadata,
    bool writeMetadata = true,
    FcScanStamp? stamp,
    void Function(FcScanStage stage)? onStage,
  }) async {
    String? savedPath;
    try {
      var bytes = await _read(raw);
      int width;
      int height;

      if (stamp != null && metadata != null) {
        onStage?.call(FcScanStage.stamping);
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

      onStage?.call(FcScanStage.compressing);
      final outcome = await FcImageCompressor.toBudget(
        bytes: bytes,
        maxBytes: maxBytes,
        width: width,
        height: height,
      );

      final file = await FcImageStore.save(outcome.data);
      savedPath = file.path;

      final embed = writeMetadata && metadata != null;
      if (embed) {
        onStage?.call(FcScanStage.writingMetadata);
        // After compression: a JPEG re-encode drops EXIF.
        await FcExifWriter.write(file.path, metadata);
      }

      return fcSuccess(
        FcScannedPage(
          file: XFile(file.path),
          sizeBytes: outcome.sizeBytes,
          width: outcome.width,
          height: outcome.height,
          wasCompressed: outcome.wasCompressed,
          quality: outcome.quality,
          metadata: embed || stamp != null ? metadata : null,
        ),
      );
    } on FcCameraException catch (error) {
      if (savedPath != null) await FcImageStore.deleteQuietly(savedPath);
      return fcFailure(error.toFailure());
    } catch (error) {
      if (savedPath != null) await FcImageStore.deleteQuietly(savedPath);
      return fcFailure(UnknownFailure('Processing failed: $error'));
    }
  }

  @override
  Future<void> discard({List<FcScannedPage> pages = const []}) async {
    await Future.wait([
      for (final page in pages) FcImageStore.deleteQuietly(page.file.path),
    ]);
    await clearCache();
  }

  @override
  Future<void> clearCache() => _engine.clearCache();

  static Future<Uint8List> _read(XFile raw) async {
    try {
      return await raw.readAsBytes();
    } catch (error, stackTrace) {
      throw StorageException(
        'Could not read the scanned page.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Reads the header only; no full decode of the page.
  static Future<(int, int)> _dimensionsOf(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (descriptor.width, descriptor.height);
    } catch (error, stackTrace) {
      throw ImageProcessingException(
        'The scanned page is not a readable image.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
