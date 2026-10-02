import 'package:image_picker/image_picker.dart';

import '../../core/error/fc_camera_exception.dart';
import 'fc_capture_source.dart';

/// Thin wrapper over `image_picker`.
///
/// Injectable so the capture cubit is testable without a platform channel.
class FcImageSource {
  FcImageSource({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Returns `null` when the user backs out — a cancellation is not an error.
  ///
  /// No `maxWidth`/`imageQuality` here on purpose: `image_picker` would
  /// re-encode before we ever see the pixels, so the stamp would be drawn onto
  /// an already-degraded image and compressed a second time afterwards.
  Future<XFile?> pick(FcCaptureSource source) async {
    try {
      return await _picker.pickImage(
        source: switch (source) {
          FcCaptureSource.camera => ImageSource.camera,
          FcCaptureSource.gallery => ImageSource.gallery,
        },
      );
    } catch (error, stackTrace) {
      throw CameraException(
        'Could not read an image from ${source.name}.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
