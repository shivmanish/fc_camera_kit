import 'package:equatable/equatable.dart';

import '../../../../../core/error/fc_camera_failure.dart';
import '../../../../../core/image/fc_image_pipeline.dart';
import '../../../domain/entities/fc_face_result.dart';

sealed class FcFaceSessionState extends Equatable {
  const FcFaceSessionState();

  @override
  List<Object?> get props => [];
}

/// Waiting for the shutter.
final class FcFaceSessionLive extends FcFaceSessionState {
  const FcFaceSessionLive();
}

/// The taken photo is being stamped, compressed and tagged.
final class FcFaceSessionProcessing extends FcFaceSessionState {
  const FcFaceSessionProcessing({
    required this.photoPath,
    required this.stages,
    this.stage,
  });

  /// Shown frozen in the circle while this runs.
  final String photoPath;
  final List<FcImageStage> stages;

  /// `null` until the first stage starts.
  final FcImageStage? stage;

  @override
  List<Object?> get props => [photoPath, stages, stage];
}

final class FcFaceSessionCompleted extends FcFaceSessionState {
  const FcFaceSessionCompleted(this.result);

  final FcFaceResult result;

  @override
  List<Object?> get props => [result];
}

final class FcFaceSessionFailed extends FcFaceSessionState {
  const FcFaceSessionFailed(this.failure);

  final FcCameraFailure failure;

  @override
  List<Object?> get props => [failure];
}
