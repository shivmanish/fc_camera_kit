import '../../../../core/error/fc_camera_exception.dart';
import '../../../../core/error/fc_camera_failure.dart';
import '../../../../core/error/fc_exception_mapper.dart';
import '../../../../core/image/fc_image_pipeline.dart';
import '../../../../core/image/fc_image_store.dart';
import '../../../../core/utils/fc_result.dart';
import '../../domain/entities/fc_face_capture.dart';
import '../../domain/repositories/fc_face_repository.dart';

final class FcFaceRepositoryImpl implements FcFaceRepository {
  const FcFaceRepositoryImpl();

  @override
  Future<FcResult<FcProcessedImage>> process(
    FcFaceCapture capture, {
    required int maxBytes,
    bool writeMetadata = true,
    FcStampSpec? stamp,
    void Function(FcImageStage stage)? onStage,
  }) async {
    try {
      final image = await FcImagePipeline.run(
        capture.file,
        maxBytes: maxBytes,
        metadata: capture.metadata,
        writeMetadata: writeMetadata,
        stamp: stamp,
        onStage: onStage,
      );
      // The raw camera file is ours to remove once the result exists.
      await FcImageStore.deleteQuietly(capture.file.path);
      return fcSuccess(image);
    } on FcCameraException catch (error) {
      return fcFailure(error.toFailure());
    } catch (error) {
      return fcFailure(UnknownFailure('Processing failed: $error'));
    }
  }

  @override
  Future<void> discard(String path) => FcImageStore.deleteQuietly(path);
}
