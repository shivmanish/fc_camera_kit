import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../core/image/metadata/fc_photo_metadata.dart';

/// A finished photo: stamped, under budget, metadata embedded.
///
/// Carries the numbers the pipeline already knows, so callers never re-decode
/// the file just to learn how big it is.
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

  /// The processed image, in an app-owned directory.
  ///
  /// `XFile`, not `File`: it is what `image_picker` returns and what the rest
  /// of the ecosystem accepts. `File(result.file.path)` is the one-line
  /// escape hatch on Android and iOS.
  final XFile file;

  /// Exactly what was stamped and written to EXIF.
  final FcPhotoMetadata metadata;

  final int sizeBytes;
  final int width;
  final int height;

  /// `false` when the first full-quality encode already fit the budget.
  final bool wasCompressed;

  /// JPEG quality the result was encoded at.
  final int quality;

  double get sizeKb => sizeBytes / 1024;
  double get sizeMb => sizeBytes / (1024 * 1024);

  @override
  List<Object?> get props => [
    // XFile has no value equality, so compare by what identifies it.
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
