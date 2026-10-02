import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Rules for getting an image under a byte budget.
///
/// Quality is spent before resolution on purpose: dropping JPEG quality from
/// 95 to 80 is invisible on a photograph, while downscaling is immediately
/// obvious when someone zooms in to read a stamped ID.
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

  /// First attempt. High enough to be visually lossless on a photo.
  final int startQuality;

  /// Never encode below this — past it, artefacts are visible.
  final int minQuality;

  /// Never shrink the shorter edge below this.
  final int minDimension;

  /// Applied per step once quality alone cannot reach the budget.
  final double downscaleFactor;

  /// How many times the image may be scaled down before giving up.
  final int maxDownscaleRounds;

  /// How many quality settings to try between [startQuality] and [minQuality].
  final int qualityRungs;

  /// Quality settings to try, highest first.
  ///
  /// A descending ladder rather than a binary search: every attempt ships the
  /// whole frame across the platform channel, so the count of attempts matters
  /// far more than landing on the mathematically highest quality that fits.
  /// This stops at the first rung under budget — one encode in the common
  /// case, [qualityRungs] at worst, where a binary search cost six or more.
  List<int> get qualitySteps {
    final span = startQuality - minQuality;

    return [
      for (var i = 0; i < qualityRungs; i++)
        startQuality - (span * i / (qualityRungs - 1)).round(),
    ];
  }

  /// Shorter edge for the next downscale step, or `null` once [minDimension]
  /// is reached and there is nothing left to give.
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

/// What the compressor did, so callers need not re-derive it.
final class FcCompressionOutcome extends Equatable {
  const FcCompressionOutcome({
    required this.data,
    required this.quality,
    required this.width,
    required this.height,
    required this.wasCompressed,
  });

  /// The encoded JPEG. Carried here so callers never re-encode to get it.
  final Uint8List data;

  final int quality;
  final int width;
  final int height;

  /// `false` when the first full-quality encode already fit the budget.
  final bool wasCompressed;

  int get sizeBytes => data.length;

  @override
  // Compared by length rather than content: byte-for-byte equality on a
  // multi-megabyte buffer is expensive and never what a caller means.
  List<Object?> get props => [
    data.length,
    quality,
    width,
    height,
    wasCompressed,
  ];
}
