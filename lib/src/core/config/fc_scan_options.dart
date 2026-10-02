import 'package:equatable/equatable.dart';

/// Where the scanner may take pages from.
enum FcScanSource { camera, gallery, cameraAndGallery }

/// How much clean-up the platform scanner offers after capture.
enum FcScanEnhancement {
  /// Crop and rotate only.
  basic,

  /// Adds filters (grayscale, B&W, colour).
  filters,

  /// Adds ML clean-up such as shadow and stain removal (Android).
  full,
}

/// Scanner defaults, set once through `FcCameraKit.init(scan: ...)`.
final class FcScanOptions extends Equatable {
  const FcScanOptions({
    this.maxPages = 1,
    this.source = FcScanSource.camera,
    this.enhancement = FcScanEnhancement.full,
    this.embedMetadata = true,
    this.stamp = false,
  });

  /// Must be positive; `init()` and `scan()` fail cleanly otherwise.
  final int maxPages;
  final FcScanSource source;
  final FcScanEnhancement enhancement;

  /// Writes who / when / where into each page's EXIF.
  final bool embedMetadata;

  /// Burns who / when / where onto each page, styled like `capture()`.
  /// Off by default: documents are usually kept unmarked.
  final bool stamp;

  FcScanOptions copyWith({
    int? maxPages,
    FcScanSource? source,
    FcScanEnhancement? enhancement,
    bool? embedMetadata,
    bool? stamp,
  }) => FcScanOptions(
    maxPages: maxPages ?? this.maxPages,
    source: source ?? this.source,
    enhancement: enhancement ?? this.enhancement,
    embedMetadata: embedMetadata ?? this.embedMetadata,
    stamp: stamp ?? this.stamp,
  );

  @override
  List<Object?> get props => [
    maxPages,
    source,
    enhancement,
    embedMetadata,
    stamp,
  ];
}
