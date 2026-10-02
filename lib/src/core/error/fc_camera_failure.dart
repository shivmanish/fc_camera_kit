import 'package:equatable/equatable.dart';

/// Domain level error. Carried inside Cubit states, never thrown.
///
/// Switch over it exhaustively to map errors onto your own UI copy:
/// ```dart
/// final text = switch (failure) {
///   PermissionFailure(:final permanentlyDenied) when permanentlyDenied =>
///     'Enable the permission in Settings',
///   SizeLimitFailure() => 'Photo is too large',
///   _ => failure.message,
/// };
/// ```
sealed class FcCameraFailure extends Equatable {
  const FcCameraFailure(this.message);

  /// Developer facing description. Not localised, do not show it to end users.
  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType($message)';
}

/// A required runtime permission is not granted.
final class PermissionFailure extends FcCameraFailure {
  const PermissionFailure(
    super.message, {
    required this.permission,
    required this.permanentlyDenied,
  });

  /// Which permission blocked the flow, e.g. `camera`, `location`.
  final String permission;

  /// `true` when the user must fix it from App Settings.
  final bool permanentlyDenied;

  @override
  List<Object?> get props => [...super.props, permission, permanentlyDenied];
}

/// Camera hardware was unavailable or misbehaved.
final class CameraFailure extends FcCameraFailure {
  const CameraFailure(super.message);
}

/// Filesystem access failed.
final class StorageFailure extends FcCameraFailure {
  const StorageFailure(super.message);
}

/// Stamping, encoding or compression failed.
final class ImageProcessingFailure extends FcCameraFailure {
  const ImageProcessingFailure(super.message);
}

/// The result stayed above the configured byte budget.
final class SizeLimitFailure extends FcCameraFailure {
  const SizeLimitFailure(
    super.message, {
    required this.actualBytes,
    required this.limitBytes,
  });

  final int actualBytes;
  final int limitBytes;

  @override
  List<Object?> get props => [...super.props, actualBytes, limitBytes];
}

/// EXIF read or write failed.
final class MetadataFailure extends FcCameraFailure {
  const MetadataFailure(super.message);
}

/// No location fix within the configured timeout.
final class LocationFailure extends FcCameraFailure {
  const LocationFailure(super.message);
}

/// The kit was not initialised, or was given invalid configuration.
final class ConfigurationFailure extends FcCameraFailure {
  const ConfigurationFailure(super.message);
}

/// The user backed out of the flow. Treat as a no-op, not an error.
final class CancelledFailure extends FcCameraFailure {
  const CancelledFailure([super.message = 'Cancelled by user']);
}

/// Anything not covered above.
final class UnknownFailure extends FcCameraFailure {
  const UnknownFailure(super.message);
}
