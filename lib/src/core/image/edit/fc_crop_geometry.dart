import 'dart:math' as math;
import 'dart:ui';

enum FcCropAspect {
  free,

  /// Matches the photo's own aspect.
  original,
  square,
}

enum FcCropHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
  inside,
}

/// Crop maths in fractions of the turned photo.
abstract final class FcCropGeometry {
  static const double minSide = 0.1;

  // Ratio is in photo fractions, so "original" is 1, not the pixel ratio.
  static double? ratioOf(FcCropAspect aspect, Size turned) => switch (aspect) {
    FcCropAspect.free => null,
    FcCropAspect.original => 1,
    FcCropAspect.square => turned.height / turned.width,
  };

  static Rect fit(double ratio) {
    var width = 1.0;
    var height = 1 / ratio;
    if (height > 1) {
      height = 1;
      width = ratio;
    }
    return Rect.fromLTWH((1 - width) / 2, (1 - height) / 2, width, height);
  }

  static Rect drag(
    Rect crop,
    FcCropHandle handle,
    Offset delta, {
    double? ratio,
  }) {
    if (handle == FcCropHandle.inside) return _move(crop, delta);
    return ratio == null
        ? _resizeFree(crop, handle, delta)
        : _resizeHeld(crop, handle, delta, ratio);
  }

  static Rect _move(Rect crop, Offset delta) => Rect.fromLTWH(
    (crop.left + delta.dx).clamp(0, 1 - crop.width),
    (crop.top + delta.dy).clamp(0, 1 - crop.height),
    crop.width,
    crop.height,
  );

  static Rect _resizeFree(Rect crop, FcCropHandle handle, Offset delta) {
    var left = crop.left;
    var top = crop.top;
    var right = crop.right;
    var bottom = crop.bottom;

    if (_movesLeft(handle)) {
      left = (left + delta.dx).clamp(0, right - minSide);
    }
    if (_movesRight(handle)) {
      right = (right + delta.dx).clamp(left + minSide, 1);
    }
    if (_movesTop(handle)) {
      top = (top + delta.dy).clamp(0, bottom - minSide);
    }
    if (_movesBottom(handle)) {
      bottom = (bottom + delta.dy).clamp(top + minSide, 1);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  // Held ratios resize from corners only, pivoting on the opposite corner.
  static Rect _resizeHeld(
    Rect crop,
    FcCropHandle handle,
    Offset delta,
    double ratio,
  ) {
    final anchor = switch (handle) {
      FcCropHandle.topLeft => crop.bottomRight,
      FcCropHandle.topRight => crop.bottomLeft,
      FcCropHandle.bottomRight => crop.topLeft,
      FcCropHandle.bottomLeft => crop.topRight,
      _ => null,
    };
    if (anchor == null) return crop;

    final sx = _movesLeft(handle) ? -1.0 : 1.0;
    final sy = _movesTop(handle) ? -1.0 : 1.0;

    // Follow the axis the finger moved further.
    final byX = crop.width + sx * delta.dx;
    final byY = (crop.height + sy * delta.dy) * ratio;
    var width = (byX - crop.width).abs() >= (byY - crop.width).abs()
        ? byX
        : byY;

    final roomX = sx < 0 ? anchor.dx : 1 - anchor.dx;
    final roomY = sy < 0 ? anchor.dy : 1 - anchor.dy;
    final maxWidth = math.min(roomX, roomY * ratio);
    final minWidth = math.max(minSide, minSide * ratio);
    width = width.clamp(math.min(minWidth, maxWidth), maxWidth);
    final height = width / ratio;

    return Rect.fromLTWH(
      sx < 0 ? anchor.dx - width : anchor.dx,
      sy < 0 ? anchor.dy - height : anchor.dy,
      width,
      height,
    );
  }

  static bool _movesLeft(FcCropHandle handle) =>
      handle == FcCropHandle.topLeft ||
      handle == FcCropHandle.left ||
      handle == FcCropHandle.bottomLeft;

  static bool _movesRight(FcCropHandle handle) =>
      handle == FcCropHandle.topRight ||
      handle == FcCropHandle.right ||
      handle == FcCropHandle.bottomRight;

  static bool _movesTop(FcCropHandle handle) =>
      handle == FcCropHandle.topLeft ||
      handle == FcCropHandle.top ||
      handle == FcCropHandle.topRight;

  static bool _movesBottom(FcCropHandle handle) =>
      handle == FcCropHandle.bottomLeft ||
      handle == FcCropHandle.bottom ||
      handle == FcCropHandle.bottomRight;
}
