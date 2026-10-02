import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../../config/fc_camera_kit.dart';

/// Look of the who/when/where stamp.
///
/// There is no font size here on purpose. The badge is sized first — half the
/// frame for an overlay, the full frame for an extended panel — and the type is
/// then solved to fill it. That keeps the stamp the same visual weight on a
/// 1 MP thumbnail and a 12 MP photo, which a fixed point size cannot do.
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

  /// Used for the secondary lines, so the name stays dominant.
  final Color mutedTextColor;

  /// Tint laid over the blurred strip.
  ///
  /// Deliberately light — the blur already separates text from detail, so the
  /// scrim only needs to steady the contrast, not hide the photo behind it.
  final Color scrimColor;

  /// Solid backing when the canvas is extended instead of overlaid.
  final Color panelColor;

  /// Gaussian sigma for the frosted strip. Ignored for extended canvases.
  final double blurSigma;

  /// Guard rails on the solved size, for a stamp that is one character long
  /// or a paragraph. Neither should normally bind.
  final double minFontSize;
  final double maxFontSize;

  /// Padding as a multiple of the resolved font size.
  ///
  /// Tied to the type rather than the image so the strip keeps its proportions
  /// at every resolution.
  final double paddingRatio;

  final double lineSpacing;

  /// Width of the overlay badge, as a fraction of the image width.
  ///
  /// The type is solved so the longest line plus its padding lands exactly on
  /// this, which is what keeps the badge a predictable size.
  final double overlayMaxWidthRatio;

  double paddingFor(double fontSize) => fontSize * paddingRatio;

  /// Text insets, which differ by placement.
  ///
  /// Extend pads evenly on all sides. Overlay drops the vertical inset
  /// entirely, because every pixel of strip is photo the viewer cannot see.
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
