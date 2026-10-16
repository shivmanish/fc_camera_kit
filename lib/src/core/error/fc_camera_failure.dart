import 'package:equatable/equatable.dart';

/// Domain error carried in Cubit state, never thrown; switch on it for UI copy.
sealed class FcCameraFailure extends Equatable {
  const FcCameraFailure(this.message);

  /// Developer text, not localised; do not show to users.
  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType($message)';
}

final class PermissionFailure extends FcCameraFailure {
  const PermissionFailure(
    super.message, {
    required this.permission,
    required this.permanentlyDenied,
  });

  final String permission;

  final bool permanentlyDenied;

  @override
  List<Object?> get props => [...super.props, permission, permanentlyDenied];
}

final class CameraFailure extends FcCameraFailure {
  const CameraFailure(super.message);
}

final class StorageFailure extends FcCameraFailure {
  const StorageFailure(super.message);
}

final class ImageProcessingFailure extends FcCameraFailure {
  const ImageProcessingFailure(super.message);
}

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

final class MetadataFailure extends FcCameraFailure {
  const MetadataFailure(super.message);
}

final class LocationFailure extends FcCameraFailure {
  const LocationFailure(super.message);
}

final class ConfigurationFailure extends FcCameraFailure {
  const ConfigurationFailure(super.message);
}

/// User backed out; treat as a no-op, not an error.
final class CancelledFailure extends FcCameraFailure {
  const CancelledFailure([super.message = 'Cancelled by user']);
}

final class UnknownFailure extends FcCameraFailure {
  const UnknownFailure(super.message);
}
