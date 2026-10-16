import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../error/fc_camera_exception.dart';
import 'fc_photo_edit.dart';

/// Applies an [FcPhotoEdit] to decoded pixels, on the GPU.
///
/// Quarter turns land exactly on the pixel grid, so nothing is resampled:
/// the edited photo is the original's pixels, rearranged.
abstract final class FcPhotoEditor {
  /// [source] turned and cropped as [edit] says, or [source] itself when
  /// there is nothing to do. The caller owns, and disposes, both.
  static Future<ui.Image> apply(ui.Image source, FcPhotoEdit edit) async {
    if (edit.isNone) return source;

    final width = source.width.toDouble();
    final height = source.height.toDouble();
    final turned = edit.turn(ui.Size(width, height));
    final crop = ui.Rect.fromLTRB(
      (edit.crop.left * turned.width).roundToDouble(),
      (edit.crop.top * turned.height).roundToDouble(),
      (edit.crop.right * turned.width).roundToDouble(),
      (edit.crop.bottom * turned.height).roundToDouble(),
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..translate(-crop.left, -crop.top);
    // Each turn pivots the photo back into the positive quadrant.
    switch (edit.quarterTurns % 4) {
      case 1:
        canvas
          ..translate(height, 0)
          ..rotate(math.pi / 2);
      case 2:
        canvas
          ..translate(width, height)
          ..rotate(math.pi);
      case 3:
        canvas
          ..translate(0, width)
          ..rotate(-math.pi / 2);
    }
    canvas.drawImage(source, ui.Offset.zero, ui.Paint());

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(
        math.max(1, crop.width.toInt()),
        math.max(1, crop.height.toInt()),
      );
    } catch (error, stackTrace) {
      throw ImageProcessingException(
        'Could not crop or rotate the photo.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      picture.dispose();
    }
  }
}
