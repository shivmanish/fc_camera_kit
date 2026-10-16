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

final class FcCameraReady extends FcCameraState {
  const FcCameraReady({
    required this.sensorAspect,
    this.lens = FcCameraLens.front,
    this.canSwitchLens = false,
    this.flash,
    this.capturing = false,
  });

  /// Landscape sensor ratio, so above 1.
  final double sensorAspect;
  final FcCameraLens lens;

  final bool canSwitchLens;

  /// `null` when this lens has no flash.
  final FcFlashMode? flash;

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

final class FcCameraPaused extends FcCameraState {
  const FcCameraPaused();
}

final class FcCameraError extends FcCameraState {
  const FcCameraError(this.failure);

  final FcCameraFailure failure;

  @override
  List<Object?> get props => [failure];
}
