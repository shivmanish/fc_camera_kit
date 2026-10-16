import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../core/image/metadata/fc_photo_metadata.dart';

/// A finished photo plus its size and quality, so callers needn't re-decode it.
final class FcCaptureResult extends Equatable {
  const FcCaptureResult({
    required this.file,
    required this.metadata,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.wasCompressed,
    required this.quality,
  });

  final XFile file;

  final FcPhotoMetadata metadata;

  final int sizeBytes;
  final int width;
  final int height;

  final bool wasCompressed;

  final int quality;

  double get sizeKb => sizeBytes / 1024;
  double get sizeMb => sizeBytes / (1024 * 1024);

  @override
  List<Object?> get props => [
    // XFile lacks value equality; compare its path.
    file.path,
    metadata,
    sizeBytes,
    width,
    height,
    wasCompressed,
    quality,
  ];

  @override
  bool? get stringify => true;
}
