import '../../../../core/image/fc_image_pipeline.dart';
import '../../../../core/utils/fc_result.dart';
import '../entities/fc_face_capture.dart';

abstract interface class FcFaceRepository {
  Future<FcResult<FcProcessedImage>> process(
    FcFaceCapture capture, {
    required int maxBytes,
    bool writeMetadata = true,
    FcStampSpec? stamp,
    void Function(FcImageStage stage)? onStage,
  });

  Future<void> discard(String path);
}
