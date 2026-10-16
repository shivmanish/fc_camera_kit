import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/image/metadata/fc_photo_metadata.dart';

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

  /// Set only when `embedMetadata` is on.
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

final class FcScanResult extends Equatable {
  const FcScanResult(this.pages);

  final List<FcScannedPage> pages;

  FcScannedPage get first => pages.first;

  @override
  List<Object?> get props => [pages];
}
