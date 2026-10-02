import 'package:cross_file/cross_file.dart';

import '../../../../../core/config/fc_cubit.dart';
import '../../../../../core/error/fc_camera_failure.dart';
import '../../../../../core/image/fc_image_pipeline.dart';
import '../../../../../core/image/metadata/fc_metadata_resolver.dart';
import '../../../../../core/utils/fc_result.dart';
import '../../../data/repositories/fc_face_repository_impl.dart';
import '../../../domain/entities/fc_face_capture.dart';
import '../../../domain/entities/fc_face_observation.dart';
import '../../../domain/entities/fc_face_result.dart';
import '../../../domain/repositories/fc_face_repository.dart';
import 'fc_face_session_state.dart';

/// The taken selfie → a finished [FcFaceResult]. Always ends in completed or
/// failed, and leaves no file behind on failure.
class FcFaceSessionCubit
    extends FcCubit<FcFaceSessionState, FcFaceResult, XFile> {
  FcFaceSessionCubit({FcFaceRepository? repository, DateTime Function()? clock})
    : _repository = repository ?? const FcFaceRepositoryImpl(),
      _now = clock ?? DateTime.now,
      super(initialState: const FcFaceSessionLive());

  final FcFaceRepository _repository;
  final DateTime Function() _now;

  bool get isBusy => state is FcFaceSessionProcessing;

  Future<void> process({
    required XFile photo,
    required FcFaceObservation face,
    required int maxBytes,
    required bool writeMetadata,
    required FcMetadataResolver resolveMetadata,
    FcStampSpec? stamp,
  }) async {
    if (isBusy || isClosed) {
      await _repository.discard(photo.path);
      return;
    }

    final stages = FcImageStage.planFor(
      stamp: stamp != null,
      writeMetadata: writeMetadata,
    );
    FcFaceSessionProcessing progress([FcImageStage? stage]) =>
        FcFaceSessionProcessing(
          photoPath: photo.path,
          stages: stages,
          stage: stage,
        );

    final capturedAt = _now();
    safeEmit(progress());
    try {
      final metadata = await resolveMetadata();
      final failure = metadata.failureOrNull;
      if (failure != null) return await _fail(failure, photo.path);

      final capture = FcFaceCapture(
        file: photo,
        capturedAt: capturedAt,
        face: face,
        metadata: metadata.valueOrNull,
      );
      final processed = await _repository.process(
        capture,
        maxBytes: maxBytes,
        writeMetadata: writeMetadata,
        stamp: stamp,
        onStage: (stage) => safeEmit(progress(stage)),
      );

      final image = processed.valueOrNull;
      if (image == null) {
        return await _fail(processed.failureOrNull!, photo.path);
      }
      // Nobody is waiting any more; leave nothing on disk.
      if (isClosed) return await _repository.discard(image.file.path);

      safeEmit(
        FcFaceSessionCompleted(
          FcFaceResult(
            file: image.file,
            width: image.width,
            height: image.height,
            sizeBytes: image.sizeBytes,
            capturedAt: capturedAt,
            livenessPassed: true,
            face: face.box,
            pose: face.pose,
            stamped: image.stamped,
            metadata: writeMetadata || image.stamped ? capture.metadata : null,
          ),
        ),
      );
    } catch (error) {
      await _fail(UnknownFailure('Face scan failed: $error'), photo.path);
    }
  }

  /// Ends in failure; for failures raised outside the cubit.
  void fail(FcCameraFailure failure) => safeEmit(FcFaceSessionFailed(failure));

  /// Back to waiting for the shutter, e.g. after Try again.
  void reset() => safeEmit(const FcFaceSessionLive());

  Future<void> _fail(FcCameraFailure failure, String photoPath) async {
    await _repository.discard(photoPath);
    safeEmit(FcFaceSessionFailed(failure));
  }
}
