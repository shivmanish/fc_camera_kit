import 'dart:math';

import '../entities/fc_face_observation.dart';
import '../entities/fc_face_rules.dart';

enum _Eyes { unknown, open, closed }

/// Counts real blinks of one tracked face: eyes open → closed → open again
/// within [FcFaceRules.blinkWindow].
final class FcBlinkTracker {
  FcBlinkTracker({required this.rules, DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final FcFaceRules rules;
  final DateTime Function() _now;

  int? _trackingId;
  _Eyes _eyes = _Eyes.unknown;
  DateTime? _closedAt;
  int _blinks = 0;

  bool get satisfied => _blinks >= rules.blinks;

  void observe(FcFaceObservation face) {
    // A different face (another person, a photo swapped in) starts over.
    if (face.trackingId != _trackingId) {
      reset();
      _trackingId = face.trackingId;
    }
    if (satisfied) return;

    final left = face.leftEyeOpen;
    final right = face.rightEyeOpen;
    if (left == null || right == null) return;

    // Both eyes must agree: a wink or a squint is not a blink.
    final open = min(left, right) > rules.eyesOpenAbove;
    final closed = max(left, right) < rules.eyesClosedBelow;

    switch (_eyes) {
      case _Eyes.unknown:
        if (open) _eyes = _Eyes.open;
      case _Eyes.open:
        if (closed) {
          _eyes = _Eyes.closed;
          _closedAt = _now();
        }
      case _Eyes.closed:
        final shutFor = _now().difference(_closedAt!);
        if (open) {
          if (shutFor <= rules.blinkWindow) _blinks++;
          _eyes = _Eyes.open;
        } else if (shutFor > rules.blinkWindow) {
          // Held shut too long: not a blink; wait for the eyes to open.
          _eyes = _Eyes.unknown;
        }
    }
  }

  void reset() {
    _trackingId = null;
    _eyes = _Eyes.unknown;
    _closedAt = null;
    _blinks = 0;
  }
}
