import 'dart:math';
import 'dart:ui';

/// Face oval on screen and in the frame; shared by drawing and face checks.
abstract final class FcFaceFrameGeometry {
  /// Height / width.
  static const double faceAspect = 1.3;

  /// Portrait height capped at 54% to leave room for hint and shutter.
  static Rect ovalFor(Size size) {
    if (size.isEmpty) return Rect.zero;

    if (size.width > size.height) {
      var height = size.height * 0.8;
      var width = height / faceAspect;
      if (width > size.width * 0.45) {
        width = size.width * 0.45;
        height = width * faceAspect;
      }
      return Rect.fromCenter(
        center: Offset(size.width * 0.34, size.height / 2),
        width: width,
        height: height,
      );
    }

    var width = size.width * 0.84;
    var height = width * faceAspect;
    if (height > size.height * 0.54) {
      height = size.height * 0.54;
      width = height / faceAspect;
    }
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: width,
      height: height,
    );
  }

  /// Plugins report the landscape sensor ratio; portrait inverts it.
  static double uprightAspect(double sensorAspect, {required bool landscape}) =>
      landscape ? sensorAspect : 1 / sensorAspect;

  /// Oval as 0–1 fractions of the cover-fit frame; [mirrored] flips x.
  static Rect ovalInFrame(
    Size size,
    double uprightAspect, {
    bool mirrored = true,
  }) {
    if (size.isEmpty || uprightAspect <= 0) return Rect.zero;

    // Cover-fit: scale to fill both sides, crop overflow evenly.
    final scale = max(size.width / uprightAspect, size.height);
    final shownWidth = uprightAspect * scale;
    final shownHeight = scale;
    final dx = (size.width - shownWidth) / 2;
    final dy = (size.height - shownHeight) / 2;

    final oval = ovalFor(size);
    final left = (oval.left - dx) / shownWidth;
    final right = (oval.right - dx) / shownWidth;
    return Rect.fromLTRB(
      mirrored ? 1 - right : left,
      (oval.top - dy) / shownHeight,
      mirrored ? 1 - left : right,
      (oval.bottom - dy) / shownHeight,
    );
  }
}
