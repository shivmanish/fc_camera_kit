import 'dart:async';

import 'package:flutter/foundation.dart';

import '../error/fc_camera_failure.dart';

/// Reports a flow's single outcome to the host's callbacks.
///
/// Exactly one callback fires, however the flow ends. A screen cubit owns one
/// and calls [dispose] from its `close()`, which covers the page being torn
/// down from outside (e.g. `pushAndRemoveUntil`).
final class FcFlowReporter<T> {
  FcFlowReporter({this.onCompleted, this.onCancelled, this.onFailed});

  final ValueChanged<T>? onCompleted;
  final VoidCallback? onCancelled;

  /// Without it, a failure is reported as a cancel.
  final ValueChanged<FcCameraFailure>? onFailed;

  bool _reported = false;

  bool get reported => _reported;

  /// `true` when a failure would be handled by the host rather than shown.
  bool get handlesFailures => onFailed != null;

  void completed(T value) => _once(() => onCompleted?.call(value));

  void cancelled() => _once(() => onCancelled?.call());

  void failed(FcCameraFailure failure) {
    final onFailed = this.onFailed;
    _once(
      onFailed == null ? () => onCancelled?.call() : () => onFailed(failure),
    );
  }

  /// Reports a cancel if nothing was reported, deferred so host code never
  /// runs while the widget tree is being torn down.
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
