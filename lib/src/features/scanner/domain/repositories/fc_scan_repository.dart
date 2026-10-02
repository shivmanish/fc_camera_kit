import 'package:cross_file/cross_file.dart';

import '../../../../core/config/fc_scan_options.dart';
import '../../../../core/image/metadata/fc_photo_metadata.dart';
import '../../../../core/utils/fc_result.dart';
import '../entities/fc_scan_result.dart';
import '../entities/fc_scan_stage.dart';
import '../entities/fc_scan_stamp.dart';

abstract interface class FcScanRepository {
  /// Opens the platform scanner. A user cancel is a `CancelledFailure`.
  Future<FcResult<List<XFile>>> acquire(FcScanOptions options);

  /// Stamps (when [stamp] is set), compresses to [maxBytes] and, when
  /// [writeMetadata] is on, embeds [metadata]. Reports each stage as it starts.
  Future<FcResult<FcScannedPage>> process(
    XFile raw, {
    required int maxBytes,
    FcPhotoMetadata? metadata,
    bool writeMetadata = true,
    FcScanStamp? stamp,
    void Function(FcScanStage stage)? onStage,
  });

  /// Removes the scanner's own copies and any [pages] already produced.
  Future<void> discard({List<FcScannedPage> pages = const []});

  /// Removes the scanner's own copies once pages are safely processed.
  Future<void> clearCache();
}
