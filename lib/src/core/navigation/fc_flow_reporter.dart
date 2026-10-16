import 'dart:async';

import 'package:flutter/foundation.dart';

import '../error/fc_camera_failure.dart';

/// Fires exactly one host callback per flow, even on external teardown.
final class FcFlowReporter<T> {
  FcFlowReporter({this.onCompleted, this.onCancelled, this.onFailed});

  final ValueChanged<T>? onCompleted;
  final VoidCallback? onCancelled;

  /// When null, failures are reported as cancels.
  final ValueChanged<FcCameraFailure>? onFailed;

  bool _reported = false;

  bool get reported => _reported;

  bool get handlesFailures => onFailed != null;

  void completed(T value) => _once(() => onCompleted?.call(value));

  void cancelled() => _once(() => onCancelled?.call());

  void failed(FcCameraFailure failure) {
    final onFailed = this.onFailed;
    _once(
      onFailed == null ? () => onCancelled?.call() : () => onFailed(failure),
    );
  }

  // Deferred so host code never runs mid tree teardown.
  void dispose() {
    if (_reported) return;
    _reported = true;
    final onCancelled = this.onCancelled;
    if (onCancelled != null) scheduleMicrotask(onCancelled);
  }

  void _once(VoidCallback report) {
    if (_reported) return;
    _reported = true;
    report();
  }
}
