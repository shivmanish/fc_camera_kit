import 'dart:math';

import '../entities/fc_face_observation.dart';
import '../entities/fc_face_rules.dart';

enum _Eyes { unknown, open, closed }

/// Counts blinks: eyes open, closed, then open within [FcFaceRules.blinkWindow].
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
    // A new tracked face (another person, a swapped photo) starts over.
    if (face.trackingId != _trackingId) {
      reset();
      _trackingId = face.trackingId;
    }
    if (satisfied) return;

    final left = face.leftEyeOpen;
    final right = face.rightEyeOpen;
    if (left == null || right == null) return;

    // Both eyes must close: a wink or squint isn't a blink.
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
          // Held shut too long; wait for the eyes to reopen.
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
