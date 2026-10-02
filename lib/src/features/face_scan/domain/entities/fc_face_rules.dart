import 'package:equatable/equatable.dart';

import 'fc_face_result.dart';

/// Thresholds for a face to count as framed, straight and live.
///
/// Framing is judged against [target]: the on-screen oval mapped into the
/// camera frame, so the rule matches what the user sees on any screen.
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

  /// A portrait phone's oval (4:3 sensor, cover-fit), used until the screen
  /// reports its real one.
  static const defaultTarget = FcFaceBox(
    left: 0.24,
    top: 0.15,
    width: 0.52,
    height: 0.5,
  );

  final int blinks;

  /// The oval, as fractions of the upright camera frame.
  final FcFaceBox target;
  final double minLuminance;

  /// How far the face centre may sit from the oval centre, as a fraction of
  /// the oval's width (left–right) and height (up–down).
  final double centerTolerance;

  /// Face width ÷ oval width: below [minFill] is too far, above [maxFill] too
  /// close.
  final double minFill;
  final double maxFill;

  final double maxYaw;
  final double maxPitch;
  final double maxRoll;
  final double eyesOpenAbove;
  final double eyesClosedBelow;

  /// Eyes must reopen within this to count as a blink, not eyes held shut.
  final Duration blinkWindow;

  /// A face may be out of bounds this long (one jittery frame) before the
  /// blink has to be done again.
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
