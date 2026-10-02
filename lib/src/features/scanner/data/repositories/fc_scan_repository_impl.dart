import 'package:cross_file/cross_file.dart';

import '../../../../core/config/fc_scan_options.dart';
import '../../../../core/error/fc_camera_exception.dart';
import '../../../../core/error/fc_camera_failure.dart';
import '../../../../core/error/fc_exception_mapper.dart';
import '../../../../core/image/fc_image_pipeline.dart';
import '../../../../core/image/fc_image_store.dart';
import '../../../../core/image/metadata/fc_photo_metadata.dart';
import '../../../../core/utils/fc_result.dart';
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
    try {
      final image = await FcImagePipeline.run(
        raw,
        maxBytes: maxBytes,
        metadata: metadata,
        writeMetadata: writeMetadata,
        stamp: stamp,
        onStage: onStage,
      );
      final embedded = writeMetadata && metadata != null;
      return fcSuccess(
        FcScannedPage(
          file: image.file,
          sizeBytes: image.sizeBytes,
          width: image.width,
          height: image.height,
          wasCompressed: image.wasCompressed,
          quality: image.quality,
          metadata: embedded || image.stamped ? metadata : null,
        ),
      );
    } on FcCameraException catch (error) {
      return fcFailure(error.toFailure());
    } catch (error) {
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
}
