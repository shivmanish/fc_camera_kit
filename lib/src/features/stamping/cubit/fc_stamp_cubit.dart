import 'package:cross_file/cross_file.dart';

import '../../../core/config/fc_camera_kit.dart';
import '../../../core/config/fc_cubit.dart';
import '../../../core/error/fc_camera_exception.dart';
import '../../../core/error/fc_camera_failure.dart';
import '../../../core/image/compressor/fc_compression_policy.dart';
import '../../../core/image/compressor/fc_image_compressor.dart';
import '../../../core/image/edit/fc_photo_edit.dart';
import '../../../core/image/fc_image_store.dart';
import '../../../core/image/metadata/fc_exif_writer.dart';
import '../../../core/image/metadata/fc_photo_metadata.dart';
import '../../../core/image/stamp/fc_stamp_renderer.dart';
import '../../../core/image/stamp/fc_stamp_style.dart';
import '../../capture/fc_capture_result.dart';
import 'fc_stamp_state.dart';

/// Stamp, compress, embed metadata; EXIF goes last as re-encoding drops it.
class FcStampCubit extends FcCubit<FcStampState, FcCaptureResult, XFile> {
  FcStampCubit() : super(initialState: const FcStampIdle());

  Future<void> process({
    required XFile source,
    required FcPhotoMetadata metadata,
    StampPlacement? placement,
    String? dateFormat,
    int? maxBytes,
    FcStampStyle style = const FcStampStyle(),
    FcCompressionPolicy policy = const FcCompressionPolicy(),
    FcPhotoEdit edit = FcPhotoEdit.none,
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
        edit: edit,
      );

      safeEmit(const FcStampProcessing(FcStampStage.compressing));

      final outcome = await FcImageCompressor.toBudget(
        bytes: stamped.bytes,
        // Leave headroom for the EXIF block.
        maxBytes: (maxBytes ?? kit.maxBytes) - FcExifWriter.reservedBytes,
        width: stamped.width,
        height: stamped.height,
        policy: policy,
      );

      final file = await FcImageStore.save(outcome.data);

      safeEmit(const FcStampProcessing(FcStampStage.writingMetadata));
      final embedded = await FcExifWriter.write(file.path, metadata);

      safeEmit(
        FcStampSuccess(
          FcCaptureResult(
            file: XFile(file.path),
            metadata: embedded,
            // Measured after EXIF is written.
            sizeBytes: await file.length(),
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
