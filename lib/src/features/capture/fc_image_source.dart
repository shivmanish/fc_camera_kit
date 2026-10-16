import 'package:image_picker/image_picker.dart';

import '../../core/error/fc_camera_exception.dart';

/// Gallery only; the system camera app would background the host app.
class FcImageSource {
  FcImageSource({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// No resize or quality args: the picker would re-encode before stamping.
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
