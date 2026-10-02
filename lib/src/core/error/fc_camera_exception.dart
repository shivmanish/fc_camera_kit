/// Thrown by data sources when a low level operation fails.
///
/// Repositories catch these and translate them into an `FcCameraFailure` so the
/// domain and presentation layers never deal with raw platform errors.
sealed class FcCameraException implements Exception {
  const FcCameraException(this.message, {this.cause, this.stackTrace});

  final String message;

  /// Original platform error, kept for logging only.
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// A runtime permission was denied, or permanently denied by the OS.
final class PermissionException extends FcCameraException {
  const PermissionException(
    super.message, {
    required this.permanentlyDenied,
    super.cause,
    super.stackTrace,
  });

  /// `true` when only App Settings can recover the permission.
  final bool permanentlyDenied;
}

/// The camera hardware could not be opened, configured or used.
final class CameraException extends FcCameraException {
  const CameraException(super.message, {super.cause, super.stackTrace});
}

/// Reading, writing or deleting a file on disk failed.
final class StorageException extends FcCameraException {
  const StorageException(super.message, {super.cause, super.stackTrace});
}

/// Decoding, stamping, encoding or compressing an image failed.
final class ImageProcessingException extends FcCameraException {
  const ImageProcessingException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// The image could not be brought under the configured size budget.
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

/// Reading or writing EXIF metadata failed.
final class MetadataException extends FcCameraException {
  const MetadataException(super.message, {super.cause, super.stackTrace});
}

/// A device location fix could not be obtained in time.
final class LocationException extends FcCameraException {
  const LocationException(super.message, {super.cause, super.stackTrace});
}

/// The kit was used before `FcCameraKit.initialize`, or configured wrongly.
final class ConfigurationException extends FcCameraException {
  const ConfigurationException(super.message, {super.cause, super.stackTrace});
}
