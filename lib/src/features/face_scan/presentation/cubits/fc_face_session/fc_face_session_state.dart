import 'package:equatable/equatable.dart';

import '../../../../../core/error/fc_camera_failure.dart';
import '../../../../../core/image/fc_image_pipeline.dart';
import '../../../domain/entities/fc_face_result.dart';

sealed class FcFaceSessionState extends Equatable {
  const FcFaceSessionState();

  @override
  List<Object?> get props => [];
}

final class FcFaceSessionLive extends FcFaceSessionState {
  const FcFaceSessionLive();
}

final class FcFaceSessionProcessing extends FcFaceSessionState {
  const FcFaceSessionProcessing({
    required this.photoPath,
    required this.stages,
    this.stage,
  });

  /// Shown frozen in the circle meanwhile.
  final String photoPath;
  final List<FcImageStage> stages;

  /// `null` before the first stage.
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
