import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../../config/fc_camera_kit.dart';

/// Stamp look; font size is solved to fill the badge, so none is set here.
final class FcStampStyle extends Equatable {
  const FcStampStyle({
    this.textColor = const Color(0xFFFFFFFF),
    this.mutedTextColor = const Color(0xCCFFFFFF),
    this.scrimColor = const Color(0x40000000),
    this.panelColor = const Color(0xFF101418),
    this.blurSigma = 14,
    this.minFontSize = 10,
    this.maxFontSize = 96,
    this.paddingRatio = 0.5,
    this.lineSpacing = 1.32,
    this.overlayMaxWidthRatio = 0.5,
  }) : assert(minFontSize <= maxFontSize, 'bad font range'),
       assert(
         overlayMaxWidthRatio > 0 && overlayMaxWidthRatio <= 1,
         'ratio must be a fraction of the width',
       );

  final Color textColor;

  final Color mutedTextColor;

  final Color scrimColor;

  final Color panelColor;

  /// Overlay only.
  final double blurSigma;

  /// Clamp on the solved size.
  final double minFontSize;
  final double maxFontSize;

  /// Multiple of the font size, so proportions hold at any resolution.
  final double paddingRatio;

  final double lineSpacing;

  /// Overlay badge width as a fraction of the image width.
  final double overlayMaxWidthRatio;

  double paddingFor(double fontSize) => fontSize * paddingRatio;

  // Overlay has no vertical inset: every strip pixel hides photo.
  ({double top, double bottom, double horizontal}) insetsFor(
    StampPlacement placement,
    double fontSize,
  ) {
    final unit = paddingFor(fontSize);

    return switch (placement) {
      StampPlacement.extend => (top: unit, bottom: unit, horizontal: unit),
      StampPlacement.overlay => (top: 0, bottom: 0, horizontal: unit),
    };
  }

  @override
  List<Object?> get props => [
    textColor,
    mutedTextColor,
    scrimColor,
    panelColor,
    blurSigma,
    minFontSize,
    maxFontSize,
    paddingRatio,
    lineSpacing,
    overlayMaxWidthRatio,
  ];
}
