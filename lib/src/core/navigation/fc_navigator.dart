import 'dart:async';

import 'package:flutter/material.dart';

/// Opens and closes kit routes; each resolves once, even if removed externally.
abstract final class FcNavigator {
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    WidgetBuilder builder, {
    bool animate = true,
  }) => _push(
    Navigator.of(context),
    _FcPageRoute<T>(builder: builder, animate: animate),
  );

  static Future<T?> showSheet<T extends Object?>(
    BuildContext context,
    WidgetBuilder builder, {
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = false,
    Color? backgroundColor,
    ShapeBorder? shape,
  }) {
    final navigator = Navigator.of(context);
    final localizations = MaterialLocalizations.of(context);

    return _push(
      navigator,
      _FcSheetRoute<T>(
        builder: builder,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        isScrollControlled: isScrollControlled,
        barrierLabel: localizations.scrimLabel,
        barrierOnTapHint: localizations.scrimOnTapHint(
          localizations.bottomSheetLabel,
        ),
        backgroundColor: backgroundColor,
        shape: shape,
        isDismissible: isDismissible,
        modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
        enableDrag: enableDrag,
        useSafeArea: useSafeArea,
      ),
    );
  }

  static Future<T?> showDialog<T extends Object?>(
    BuildContext context,
    WidgetBuilder builder, {
    bool barrierDismissible = true,
  }) {
    final navigator = Navigator.of(context, rootNavigator: true);

    return _push(
      navigator,
      _FcDialogRoute<T>(
        context: context,
        builder: builder,
        barrierDismissible: barrierDismissible,
        barrierColor:
            Theme.of(context).dialogTheme.barrierColor ?? Colors.black54,
        themes: InheritedTheme.capture(from: context, to: navigator.context),
      ),
    );
  }

  /// Removes the route owning [context], never a host route pushed above it.
  static bool close<T extends Object?>(BuildContext context, [T? result]) {
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive || route.isFirst) return false;

    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop<T>(result);
    } else {
      navigator.removeRoute(route, result);
    }
    return true;
  }

  static Future<T?> _push<T>(
    NavigatorState navigator,
    _CompletesOnce<T> route,
  ) {
    unawaited(navigator.push<T>(route));
    return route.outcome;
  }
}

mixin _CompletesOnce<T> on Route<T> {
  final Completer<T?> _outcome = Completer<T?>();

  Future<T?> get outcome => _outcome.future;

  @override
  void didComplete(T? result) {
    super.didComplete(result);
    if (!_outcome.isCompleted) _outcome.complete(result);
  }

  @override
  void dispose() {
    // Routes removed without a result never call didComplete.
    if (!_outcome.isCompleted) _outcome.complete(null);
    super.dispose();
  }
}

class _FcPageRoute<T> extends MaterialPageRoute<T> with _CompletesOnce<T> {
  _FcPageRoute({required super.builder, required this.animate});

  final bool animate;

  @override
  Duration get transitionDuration =>
      animate ? super.transitionDuration : Duration.zero;

  @override
  Duration get reverseTransitionDuration =>
      animate ? super.reverseTransitionDuration : Duration.zero;
}

class _FcSheetRoute<T> extends ModalBottomSheetRoute<T> with _CompletesOnce<T> {
  _FcSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.shape,
    super.isDismissible,
    super.modalBarrierColor,
    super.enableDrag,
    super.useSafeArea,
  });
}

class _FcDialogRoute<T> extends DialogRoute<T> with _CompletesOnce<T> {
  _FcDialogRoute({
    required super.context,
    required super.builder,
    super.barrierDismissible,
    super.barrierColor,
    super.themes,
  });
}
