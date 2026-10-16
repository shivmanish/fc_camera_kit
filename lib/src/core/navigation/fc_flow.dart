import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/fc_camera_kit.dart';
import '../error/fc_camera_failure.dart';
import '../utils/fc_result.dart';
import 'fc_navigator.dart';

/// The callbacks a flow page reports its single outcome through.
final class FcFlowCallbacks<T> {
  const FcFlowCallbacks({
    required this.onCompleted,
    required this.onCancelled,
    required this.onFailed,
  });

  final ValueChanged<T> onCompleted;
  final VoidCallback onCancelled;
  final ValueChanged<FcCameraFailure> onFailed;
}

/// Runs a kit flow page as one call that returns one [FcResult].
abstract final class FcFlow {
  static final Map<Object, Future<Object>> _inFlight = {};

  /// Pushes the page built by [page] and resolves with its outcome.
  ///
  /// A second call with the same [key] while one runs gets that run's result
  /// instead of opening the flow twice. Never throws.
  static Future<FcResult<T>> run<T extends Object>(
    BuildContext context, {
    required Object key,
    required Widget Function(FcFlowCallbacks<T> callbacks) page,
    bool animate = false,
  }) {
    final running = _inFlight[key];
    // The very same future, so both callers see one result.
    if (running != null) return running as Future<FcResult<T>>;

    final next = _run(context, page: page, animate: animate);
    _inFlight[key] = next;
    unawaited(
      next.whenComplete(() {
        if (identical(_inFlight[key], next)) _inFlight.remove(key);
      }),
    );
    return next;
  }

  static Future<FcResult<T>> _run<T extends Object>(
    BuildContext context, {
    required Widget Function(FcFlowCallbacks<T> callbacks) page,
    required bool animate,
  }) async {
    if (!FcCameraKit.instance.isInitialized) {
      return fcFailure(
        const ConfigurationFailure(
          'FcCameraKit.instance.init() must be called first.',
        ),
      );
    }

    T? result;
    FcCameraFailure? failure;
    try {
      // The page closes its own route; the callbacks only record the outcome.
      await FcNavigator.push<Object?>(
        context,
        (_) => page(
          FcFlowCallbacks<T>(
            onCompleted: (value) => result = value,
            onCancelled: () => failure = const CancelledFailure(),
            onFailed: (error) => failure = error,
          ),
        ),
        animate: animate,
      );
    } catch (error) {
      return fcFailure(UnknownFailure('Flow failed unexpectedly: $error'));
    }

    final value = result;
    if (value != null) return fcSuccess(value);
    return fcFailure(failure ?? const CancelledFailure());
  }
}
