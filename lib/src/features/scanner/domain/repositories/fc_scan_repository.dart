import 'package:cross_file/cross_file.dart';

import '../../../../core/config/fc_scan_options.dart';
import '../../../../core/image/metadata/fc_photo_metadata.dart';
import '../../../../core/utils/fc_result.dart';
import '../entities/fc_scan_result.dart';
import '../entities/fc_scan_stage.dart';
import '../entities/fc_scan_stamp.dart';

abstract interface class FcScanRepository {
  /// A user cancel returns `CancelledFailure`.
  Future<FcResult<List<XFile>>> acquire(FcScanOptions options);

  /// Stamp, compress, embed metadata; reports each stage as it starts.
  Future<FcResult<FcScannedPage>> process(
    XFile raw, {
    required int maxBytes,
    FcPhotoMetadata? metadata,
    bool writeMetadata = true,
    FcScanStamp? stamp,
    void Function(FcScanStage stage)? onStage,
  });

  /// Also deletes any [pages] already produced.
  Future<void> discard({List<FcScannedPage> pages = const []});

  /// Call once pages are safely processed.
  Future<void> clearCache();
}
