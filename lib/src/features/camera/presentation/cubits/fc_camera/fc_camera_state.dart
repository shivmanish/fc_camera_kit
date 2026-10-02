import 'package:equatable/equatable.dart';

import '../../../../../core/error/fc_camera_failure.dart';

sealed class FcCameraState extends Equatable {
  const FcCameraState();

  @override
  List<Object?> get props => [];
}

final class FcCameraStarting extends FcCameraState {
  const FcCameraStarting();
}

/// Preview is live.
final class FcCameraReady extends FcCameraState {
  const FcCameraReady({required this.sensorAspect});

  /// Width ÷ height of the sensor's frames (landscape, so above 1).
  final double sensorAspect;

  @override
  List<Object?> get props => [sensorAspect];
}

/// The app is in the background; the camera is released until it returns.
final class FcCameraPaused extends FcCameraState {
  const FcCameraPaused();
}

final class FcCameraError extends FcCameraState {
  const FcCameraError(this.failure);

  final FcCameraFailure failure;

  @override
  List<Object?> get props => [failure];
}
