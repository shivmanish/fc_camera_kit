import 'package:equatable/equatable.dart';

import 'fc_face_result.dart';

/// Face thresholds; framing is judged against the on-screen oval mapped into the frame.
final class FcFaceRules extends Equatable {
  const FcFaceRules({
    this.blinks = 1,
    this.target = defaultTarget,
    this.minLuminance = 40,
    this.centerTolerance = 0.25,
    this.minFill = 0.45,
    this.maxFill = 1.05,
    this.maxYaw = 18,
    this.maxPitch = 20,
    this.maxRoll = 15,
    this.eyesOpenAbove = 0.6,
    this.eyesClosedBelow = 0.35,
    this.blinkWindow = const Duration(milliseconds: 1500),
    this.graceAfterInvalid = const Duration(milliseconds: 700),
  });

  /// Portrait default (4:3 sensor, cover-fit) until the screen reports its oval.
  static const defaultTarget = FcFaceBox(
    left: 0.24,
    top: 0.25,
    width: 0.52,
    height: 0.5,
  );

  final int blinks;

  /// Fractions of the upright camera frame.
  final FcFaceBox target;
  final double minLuminance;

  /// Max centre offset, as a fraction of the oval's width and height.
  final double centerTolerance;

  /// Face width ÷ oval width: below is too far, above too close.
  final double minFill;
  final double maxFill;

  final double maxYaw;
  final double maxPitch;
  final double maxRoll;
  final double eyesOpenAbove;
  final double eyesClosedBelow;

  /// Eyes must reopen within this, else they were just held shut.
  final Duration blinkWindow;

  /// Grace for a jittery out-of-bounds frame before the blink resets.
  final Duration graceAfterInvalid;

  FcFaceRules copyWith({FcFaceBox? target}) => FcFaceRules(
    blinks: blinks,
    target: target ?? this.target,
    minLuminance: minLuminance,
    centerTolerance: centerTolerance,
    minFill: minFill,
    maxFill: maxFill,
    maxYaw: maxYaw,
    maxPitch: maxPitch,
    maxRoll: maxRoll,
    eyesOpenAbove: eyesOpenAbove,
    eyesClosedBelow: eyesClosedBelow,
    blinkWindow: blinkWindow,
    graceAfterInvalid: graceAfterInvalid,
  );

  @override
  List<Object?> get props => [
    blinks,
    target,
    minLuminance,
    centerTolerance,
    minFill,
    maxFill,
    maxYaw,
    maxPitch,
    maxRoll,
    eyesOpenAbove,
    eyesClosedBelow,
    blinkWindow,
    graceAfterInvalid,
  ];
}
