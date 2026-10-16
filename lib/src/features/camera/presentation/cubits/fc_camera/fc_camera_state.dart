import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../../../core/error/fc_camera_failure.dart';
import '../../../domain/entities/fc_camera_frame.dart';

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
  const FcCameraReady({
    required this.sensorAspect,
    this.lens = FcCameraLens.front,
    this.canSwitchLens = false,
    this.flash,
    this.capturing = false,
  });

  /// Width ÷ height of the sensor's frames (landscape, so above 1).
  final double sensorAspect;
  final FcCameraLens lens;

  /// The device has a camera on the other side too.
  final bool canSwitchLens;

  /// `null` when this lens has no flash to offer.
  final FcFlashMode? flash;

  /// A photo is being taken; the shutter has to wait.
  final bool capturing;

  /// [flash] is a getter so it can set `null`.
  FcCameraReady copyWith({ValueGetter<FcFlashMode?>? flash, bool? capturing}) =>
      FcCameraReady(
        sensorAspect: sensorAspect,
        lens: lens,
        canSwitchLens: canSwitchLens,
        flash: flash == null ? this.flash : flash(),
        capturing: capturing ?? this.capturing,
      );

  @override
  List<Object?> get props => [
    sensorAspect,
    lens,
    canSwitchLens,
    flash,
    capturing,
  ];
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
