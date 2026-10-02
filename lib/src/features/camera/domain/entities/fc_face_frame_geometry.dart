import 'dart:math';
import 'dart:ui';

/// Where the face oval sits for a given screen, and where that lands in the
/// camera frame. One definition read by both the UI that draws the oval and
/// the rules that judge whether a face is inside it.
abstract final class FcFaceFrameGeometry {
  /// Height ÷ width of the oval: a face is taller than it is wide.
  static const double faceAspect = 1.3;

  /// The oval for a screen of [size].
  ///
  /// Portrait: centred, slightly above middle, sized from the width so a face
  /// fills it at a normal arm's length, but never taller than 58 % of the
  /// screen, so the hint and shutter keep their room on short phones and the
  /// oval doesn't balloon on tablets. Landscape: on the left, the controls
  /// beside it on the right.
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
    if (height > size.height * 0.58) {
      height = size.height * 0.58;
      width = height / faceAspect;
    }
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.4),
      width: width,
      height: height,
    );
  }

  /// Width ÷ height of the preview as the user sees it.
  ///
  /// Camera plugins report the sensor's landscape ratio; held upright it
  /// flips.
  static double uprightAspect(double sensorAspect, {required bool landscape}) =>
      landscape ? sensorAspect : 1 / sensorAspect;

  /// The oval as fractions (0–1) of the upright camera frame, when that frame
  /// is shown cover-fit, centred, on a screen of [size].
  ///
  /// [mirrored] for the front camera: its preview is a mirror image, so what
  /// sits on the screen's left is on the frame's right.
  static Rect ovalInFrame(
    Size size,
    double uprightAspect, {
    bool mirrored = true,
  }) {
    if (size.isEmpty || uprightAspect <= 0) return Rect.zero;

    // Cover-fit: scale until both sides fill, then crop the overflow evenly.
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
