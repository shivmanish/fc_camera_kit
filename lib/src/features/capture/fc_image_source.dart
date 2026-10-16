import 'package:image_picker/image_picker.dart';

import '../../core/error/fc_camera_exception.dart';

/// The system photo picker, behind a thin wrapper over `image_picker`.
///
/// Gallery only: new photos always come from the kit's in-app camera, never
/// the system camera app, which sends the host to the background where
/// Android can kill it. Injectable so capture is testable without a platform
/// channel.
class FcImageSource {
  FcImageSource({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Returns `null` when the user backs out — a cancellation is not an error.
  ///
  /// No `maxWidth`/`imageQuality` here on purpose: `image_picker` would
  /// re-encode before we ever see the pixels, so the stamp would be drawn onto
  /// an already-degraded image and compressed a second time afterwards.
  Future<XFile?> pick() async {
    try {
      return await _picker.pickImage(source: ImageSource.gallery);
    } catch (error, stackTrace) {
      throw CameraException(
        'Could not read an image from the gallery.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
