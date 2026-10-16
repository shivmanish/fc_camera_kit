import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../error/fc_camera_exception.dart';
import 'fc_photo_edit.dart';

/// Applies an [FcPhotoEdit] on the GPU; quarter turns never resample.
abstract final class FcPhotoEditor {
  /// May return [source] itself; the caller disposes both.
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
    // Translate back into the positive quadrant after each turn.
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
