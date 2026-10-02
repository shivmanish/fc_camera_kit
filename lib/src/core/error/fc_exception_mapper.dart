import 'fc_camera_exception.dart';
import 'fc_camera_failure.dart';

extension FcCameraExceptionMapper on FcCameraException {
  FcCameraFailure toFailure({String permission = 'unknown'}) => switch (this) {
    PermissionException(:final permanentlyDenied) => PermissionFailure(
      message,
      permission: permission,
      permanentlyDenied: permanentlyDenied,
    ),
    CameraException() => CameraFailure(message),
    StorageException() => StorageFailure(message),
    ImageProcessingException() => ImageProcessingFailure(message),
    SizeLimitException(:final actualBytes, :final limitBytes) =>
      SizeLimitFailure(
        message,
        actualBytes: actualBytes,
        limitBytes: limitBytes,
      ),
    MetadataException() => MetadataFailure(message),
    LocationException() => LocationFailure(message),
    ConfigurationException() => ConfigurationFailure(message),
  };
}
