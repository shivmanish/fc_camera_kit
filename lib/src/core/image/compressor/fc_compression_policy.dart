import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Byte-budget rules; lowers quality before resolution, which shows less.
final class FcCompressionPolicy extends Equatable {
  const FcCompressionPolicy({
    this.startQuality = 95,
    this.minQuality = 70,
    this.minDimension = 1080,
    this.downscaleFactor = 0.85,
    this.maxDownscaleRounds = 4,
    this.qualityRungs = 5,
  }) : assert(
         minQuality > 0 && minQuality <= startQuality,
         'bad quality range',
       ),
       assert(qualityRungs >= 2, 'need at least a ceiling and a floor'),
       assert(downscaleFactor > 0 && downscaleFactor < 1, 'must shrink');

  final int startQuality;

  final int minQuality;

  /// Floor for the shorter edge.
  final int minDimension;

  final double downscaleFactor;

  final int maxDownscaleRounds;

  final int qualityRungs;

  // A descending ladder, not a binary search: each encode crosses the
  // platform channel, so fewer attempts beat the optimal quality.
  List<int> get qualitySteps {
    final span = startQuality - minQuality;

    return [
      for (var i = 0; i < qualityRungs; i++)
        startQuality - (span * i / (qualityRungs - 1)).round(),
    ];
  }

  /// `null` once the next step would drop below [minDimension].
  int? nextDimension(int current) {
    final next = (current * downscaleFactor).round();
    return next < minDimension ? null : next;
  }

  @override
  List<Object?> get props => [
    startQuality,
    minQuality,
    minDimension,
    downscaleFactor,
    maxDownscaleRounds,
    qualityRungs,
  ];
}

final class FcCompressionOutcome extends Equatable {
  const FcCompressionOutcome({
    required this.data,
    required this.quality,
    required this.width,
    required this.height,
    required this.wasCompressed,
  });

  final Uint8List data;

  final int quality;
  final int width;
  final int height;

  final bool wasCompressed;

  int get sizeBytes => data.length;

  @override
  // Length only; comparing megabytes of bytes is costly and never wanted.
  List<Object?> get props => [
    data.length,
    quality,
    width,
    height,
    wasCompressed,
  ];
}
