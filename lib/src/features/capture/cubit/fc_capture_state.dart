import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../../core/error/fc_camera_failure.dart';
import '../fc_capture_source.dart';

sealed class FcCaptureState extends Equatable {
  const FcCaptureState();

  @override
  List<Object?> get props => [];
}

final class FcCaptureIdle extends FcCaptureState {
  const FcCaptureIdle();
}

/// The system camera or picker is open.
final class FcCapturePicking extends FcCaptureState {
  const FcCapturePicking(this.source);

  final FcCaptureSource source;

  @override
  List<Object?> get props => [source];
}

/// Raw image in hand, not yet stamped.
final class FcCapturePicked extends FcCaptureState {
  const FcCapturePicked(this.file);

  final XFile file;

  @override
  List<Object?> get props => [file.path];
}

/// Includes the user backing out, carried as a `CancelledFailure` so callers
/// can tell a deliberate exit from a real error by switching on the failure.
final class FcCaptureFailed extends FcCaptureState {
  const FcCaptureFailed(this.failure);

  final FcCameraFailure failure;

  @override
  List<Object?> get props => [failure];
}
