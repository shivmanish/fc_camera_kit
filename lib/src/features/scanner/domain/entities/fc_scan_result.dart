import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/image/metadata/fc_photo_metadata.dart';

/// One scanned page: cropped, flattened, under budget, in an app-owned dir.
final class FcScannedPage extends Equatable {
  const FcScannedPage({
    required this.file,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.wasCompressed,
    required this.quality,
    this.metadata,
  });

  final XFile file;
  final int sizeBytes;
  final int width;
  final int height;
  final bool wasCompressed;
  final int quality;

  /// Present when `embedMetadata` is on.
  final FcPhotoMetadata? metadata;

  double get sizeKb => sizeBytes / 1024;
  double get sizeMb => sizeBytes / (1024 * 1024);

  @override
  List<Object?> get props => [
    file.path,
    sizeBytes,
    width,
    height,
    wasCompressed,
    quality,
    metadata,
  ];
}

/// Everything a scan produced, in scan order.
final class FcScanResult extends Equatable {
  const FcScanResult(this.pages);

  final List<FcScannedPage> pages;

  FcScannedPage get first => pages.first;

  @override
  List<Object?> get props => [pages];
}
