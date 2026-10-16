import 'package:equatable/equatable.dart';

enum FcScanSource { camera, gallery, cameraAndGallery }

enum FcScanEnhancement {
  basic,

  filters,

  /// ML shadow and stain removal; Android only.
  full,
}

final class FcScanOptions extends Equatable {
  const FcScanOptions({
    this.maxPages = 1,
    this.source = FcScanSource.camera,
    this.enhancement = FcScanEnhancement.full,
    this.embedMetadata = true,
    this.stamp = false,
  });

  final int maxPages;
  final FcScanSource source;
  final FcScanEnhancement enhancement;

  final bool embedMetadata;

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
