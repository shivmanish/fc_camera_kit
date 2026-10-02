import 'package:equatable/equatable.dart';

import '../../../core/error/fc_camera_failure.dart';
import '../../capture/fc_capture_result.dart';

/// Which step of the pipeline is running.
///
/// Surfaced because a 12 MP photo takes real seconds — one undifferentiated
/// spinner is the difference between "working" and "frozen".
enum FcStampStage {
  stamping('Adding the stamp'),
  compressing('Compressing'),
  writingMetadata('Writing metadata');

  const FcStampStage(this.label);

  final String label;
}

sealed class FcStampState extends Equatable {
  const FcStampState();

  @override
  List<Object?> get props => [];
}

/// Nothing has been processed yet.
final class FcStampIdle extends FcStampState {
  const FcStampIdle();
}

final class FcStampProcessing extends FcStampState {
  const FcStampProcessing(this.stage);

  final FcStampStage stage;

  @override
  List<Object?> get props => [stage];
}

final class FcStampSuccess extends FcStampState {
  const FcStampSuccess(this.result);

  final FcCaptureResult result;

  @override
  List<Object?> get props => [result];
}

final class FcStampFailure extends FcStampState {
  const FcStampFailure(this.failure);

  final FcCameraFailure failure;

  @override
  List<Object?> get props => [failure];
}
