import '../../../core/config/fc_cubit.dart';
import '../../../core/error/fc_camera_exception.dart';
import '../../../core/error/fc_camera_failure.dart';
import '../fc_capture_source.dart';
import '../fc_image_source.dart';
import 'fc_capture_state.dart';

/// Acquires a raw photo. Stamping and compression belong to `FcStampCubit`.
///
/// Split deliberately: picking is a short user interaction, processing is a
/// long CPU job, and their failures need different handling.
class FcCaptureCubit extends FcCubit<FcCaptureState, void, FcCaptureSource> {
  FcCaptureCubit({FcImageSource? source})
    : _source = source ?? FcImageSource(),
      super(initialState: const FcCaptureIdle());

  final FcImageSource _source;

  Future<void> fromCamera() => _pick(FcCaptureSource.camera);

  Future<void> fromGallery() => _pick(FcCaptureSource.gallery);

  Future<void> _pick(FcCaptureSource source) async {
    safeEmit(FcCapturePicking(source));

    try {
      final file = await _source.pick(source);

      // Backing out is a no-op, not an error — but it still has to end the
      // picking state, or the UI spins forever.
      safeEmit(
        file == null
            ? const FcCaptureFailed(CancelledFailure())
            : FcCapturePicked(file),
      );
    } on FcCameraException catch (error) {
      safeEmit(FcCaptureFailed(CameraFailure(error.message)));
    } catch (error) {
      safeEmit(FcCaptureFailed(UnknownFailure('$error')));
    }
  }

  void reset() => safeEmit(const FcCaptureIdle());
}
