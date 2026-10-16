import '../../../../core/image/fc_image_pipeline.dart';
import '../../../../core/utils/fc_result.dart';
import '../entities/fc_face_capture.dart';

abstract interface class FcFaceRepository {
  /// Stamps (when [stamp] is set), compresses to [maxBytes] and, when
  /// [writeMetadata] is on, embeds the capture's metadata.
  Future<FcResult<FcProcessedImage>> process(
    FcFaceCapture capture, {
    required int maxBytes,
    bool writeMetadata = true,
    FcStampSpec? stamp,
    void Function(FcImageStage stage)? onStage,
  });

  /// Deletes a file the flow produced but won't hand back.
  Future<void> discard(String path);
}
