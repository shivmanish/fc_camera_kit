/// Data-layer error; repositories map it to an `FcCameraFailure`.
sealed class FcCameraException implements Exception {
  const FcCameraException(this.message, {this.cause, this.stackTrace});

  final String message;

  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

final class PermissionException extends FcCameraException {
  const PermissionException(
    super.message, {
    required this.permanentlyDenied,
    super.cause,
    super.stackTrace,
  });

  final bool permanentlyDenied;
}

final class CameraException extends FcCameraException {
  const CameraException(super.message, {super.cause, super.stackTrace});
}

final class StorageException extends FcCameraException {
  const StorageException(super.message, {super.cause, super.stackTrace});
}

final class ImageProcessingException extends FcCameraException {
  const ImageProcessingException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

final class SizeLimitException extends FcCameraException {
  const SizeLimitException(
    super.message, {
    required this.actualBytes,
    required this.limitBytes,
    super.cause,
    super.stackTrace,
  });

  final int actualBytes;
  final int limitBytes;
}

final class MetadataException extends FcCameraException {
  const MetadataException(super.message, {super.cause, super.stackTrace});
}

final class LocationException extends FcCameraException {
  const LocationException(super.message, {super.cause, super.stackTrace});
}

final class ConfigurationException extends FcCameraException {
  const ConfigurationException(super.message, {super.cause, super.stackTrace});
}
