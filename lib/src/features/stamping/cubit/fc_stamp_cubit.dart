import 'package:cross_file/cross_file.dart';

import '../../../core/config/fc_camera_kit.dart';
import '../../../core/config/fc_cubit.dart';
import '../../../core/error/fc_camera_exception.dart';
import '../../../core/error/fc_camera_failure.dart';
import '../../../core/image/compressor/fc_compression_policy.dart';
import '../../../core/image/compressor/fc_image_compressor.dart';
import '../../../core/image/fc_image_store.dart';
import '../../../core/image/metadata/fc_exif_writer.dart';
import '../../../core/image/metadata/fc_photo_metadata.dart';
import '../../capture/fc_capture_result.dart';
import '../fc_stamp_renderer.dart';
import '../fc_stamp_style.dart';
import 'fc_stamp_state.dart';

/// Runs the whole processing chain: stamp, compress, embed metadata.
///
/// The three steps live together because their order is load-bearing — a JPEG
/// re-encode discards EXIF, so metadata must be written *after* compression,
/// never before.
class FcStampCubit extends FcCubit<FcStampState, FcCaptureResult, XFile> {
  FcStampCubit() : super(initialState: const FcStampIdle());

  /// Per-call arguments override the kit's configured defaults.
  Future<void> process({
    required XFile source,
    required FcPhotoMetadata metadata,
    StampPlacement? placement,
    String? dateFormat,
    int? maxBytes,
    FcStampStyle style = const FcStampStyle(),
    FcCompressionPolicy policy = const FcCompressionPolicy(),
  }) async {
    final kit = FcCameraKit.instance;

    try {
      safeEmit(const FcStampProcessing(FcStampStage.stamping));

      final original = await source.readAsBytes();
      final stamped = await FcStampRenderer.render(
        source: original,
        metadata: metadata,
        placement: placement ?? kit.placement,
        dateFormat: dateFormat ?? kit.dateFormat,
        includeDevice: kit.includeDeviceInStamp,
        style: style,
      );

      safeEmit(const FcStampProcessing(FcStampStage.compressing));

      final outcome = await FcImageCompressor.toBudget(
        bytes: stamped.bytes,
        maxBytes: maxBytes ?? kit.maxBytes,
        width: stamped.width,
        height: stamped.height,
        policy: policy,
      );

      final file = await FcImageStore.save(outcome.data);

      safeEmit(const FcStampProcessing(FcStampStage.writingMetadata));
      await FcExifWriter.write(file.path, metadata);

      safeEmit(
        FcStampSuccess(
          FcCaptureResult(
            file: XFile(file.path),
            metadata: metadata,
            sizeBytes: outcome.sizeBytes,
            width: outcome.width,
            height: outcome.height,
            wasCompressed: outcome.wasCompressed,
            quality: outcome.quality,
          ),
        ),
      );
    } on SizeLimitException catch (error) {
      safeEmit(
        FcStampFailure(
          SizeLimitFailure(
            error.message,
            actualBytes: error.actualBytes,
            limitBytes: error.limitBytes,
          ),
        ),
      );
    } on MetadataException catch (error) {
      safeEmit(FcStampFailure(MetadataFailure(error.message)));
    } on ImageProcessingException catch (error) {
      safeEmit(FcStampFailure(ImageProcessingFailure(error.message)));
    } on FcCameraException catch (error) {
      safeEmit(FcStampFailure(StorageFailure(error.message)));
    } catch (error) {
      safeEmit(FcStampFailure(UnknownFailure('$error')));
    }
  }

  void reset() => safeEmit(const FcStampIdle());
}
