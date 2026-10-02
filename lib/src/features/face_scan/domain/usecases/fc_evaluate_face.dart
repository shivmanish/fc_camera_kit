import 'package:equatable/equatable.dart';

import '../entities/fc_face_hint.dart';
import '../entities/fc_face_observation.dart';
import '../entities/fc_face_result.dart';
import '../entities/fc_face_rules.dart';
import 'fc_blink_tracker.dart';

/// The verdict on one frame: what to say, and the face when there is one.
final class FcFaceCheck extends Equatable {
  const FcFaceCheck(this.hint, [this.face]);

  final FcFaceHint hint;
  final FcFaceObservation? face;

  bool get ready => hint == FcFaceHint.ready;

  @override
  List<Object?> get props => [hint, face];
}

/// Turns detected faces into the single hint to show, tracking the blink.
final class FcEvaluateFace {
  FcEvaluateFace({
    FcFaceRules rules = const FcFaceRules(),
    DateTime Function()? clock,
  }) : _rules = rules,
       _now = clock ?? DateTime.now,
       _blinks = FcBlinkTracker(rules: rules, clock: clock);

  FcFaceRules _rules;
  FcFaceRules get rules => _rules;
  final DateTime Function() _now;
  final FcBlinkTracker _blinks;
  DateTime? _invalidSince;

  FcFaceCheck call(List<FcFaceObservation> faces, {required double luminance}) {
    final problem = _problem(faces, luminance);
    if (problem != null) {
      _markInvalid();
      return FcFaceCheck(problem, faces.length == 1 ? faces.first : null);
    }

    final face = faces.single;
    _invalidSince = null;
    _blinks.observe(face);
    return FcFaceCheck(
      _blinks.satisfied ? FcFaceHint.ready : FcFaceHint.blink,
      face,
    );
  }

  /// Where the oval now is in the camera frame, e.g. after a rotation.
  set target(FcFaceBox target) => _rules = _rules.copyWith(target: target);

  /// Forget the blink, e.g. after a retake.
  void reset() {
    _invalidSince = null;
    _blinks.reset();
  }

  FcFaceHint? _problem(List<FcFaceObservation> faces, double luminance) {
    if (luminance < rules.minLuminance) return FcFaceHint.tooDark;
    if (faces.isEmpty) return FcFaceHint.noFace;
    if (faces.length > 1) return FcFaceHint.multipleFaces;

    final face = faces.single;
    final box = face.box;
    final target = rules.target;
    if ((box.centerX - target.centerX).abs() >
            target.width * rules.centerTolerance ||
        (box.centerY - target.centerY).abs() >
            target.height * rules.centerTolerance) {
      return FcFaceHint.notCentered;
    }
    final fill = box.width / target.width;
    if (fill < rules.minFill) return FcFaceHint.moveCloser;
    if (fill > rules.maxFill) return FcFaceHint.moveBack;

    final pose = face.pose;
    if (pose.yaw.abs() > rules.maxYaw ||
        pose.pitch.abs() > rules.maxPitch ||
        pose.roll.abs() > rules.maxRoll) {
      return FcFaceHint.lookStraight;
    }
    return null;
  }

  /// One stray frame keeps the blink; staying out of bounds loses it.
  void _markInvalid() {
    final since = _invalidSince ??= _now();
    if (_now().difference(since) > rules.graceAfterInvalid) _blinks.reset();
  }
}
