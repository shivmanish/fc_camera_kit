import '../../../../../core/config/fc_cubit.dart';
import '../../../../../core/config/fc_scan_options.dart';
import '../../../../../core/error/fc_camera_failure.dart';
import '../../../../../core/image/metadata/fc_metadata_resolver.dart';
import '../../../../../core/utils/fc_result.dart';
import '../../../data/repositories/fc_scan_repository_impl.dart';
import '../../../domain/entities/fc_scan_result.dart';
import '../../../domain/entities/fc_scan_stage.dart';
import '../../../domain/entities/fc_scan_stamp.dart';
import '../../../domain/repositories/fc_scan_repository.dart';
import 'fc_scan_state.dart';

/// The scanner's name for the shared metadata resolver.
typedef FcScanMetadataResolver = FcMetadataResolver;

/// Scan → process every page → one result. Always ends in success or error.
class FcScanCubit extends FcCubit<FcScanState, FcScanResult, FcScanOptions> {
  FcScanCubit({FcScanRepository? repository})
    : _repository = repository ?? FcScanRepositoryImpl(),
      super(initialState: const FcScanIdle());

  final FcScanRepository _repository;

  bool get isBusy => state is FcScanScanning || state is FcScanProcessing;

  Future<void> start({
    required FcScanOptions options,
    required int maxBytes,
    required FcScanMetadataResolver resolveMetadata,
    FcScanStamp? stamp,
  }) async {
    if (isBusy || isClosed) return;

    final pages = <FcScannedPage>[];
    try {
      safeEmit(const FcScanScanning());
      final acquired = await _repository.acquire(options);
      final raws = acquired.valueOrNull;
      if (raws == null) return await _fail(acquired.failureOrNull!);
      if (isClosed) return await _repository.discard();

      final stages = FcScanStage.planFor(
        stamp: stamp != null,
        writeMetadata: options.embedMetadata,
      );
      FcScanProcessing progress(int index, [FcScanStage? stage]) =>
          FcScanProcessing(
            page: index + 1,
            total: raws.length,
            preview: raws[index],
            stages: stages,
            stage: stage,
          );

      safeEmit(progress(0));
      final metadata = await resolveMetadata();
      if (metadata.isLeft()) return await _fail(metadata.failureOrNull!);

      for (var i = 0; i < raws.length; i++) {
        // Nobody is waiting any more; leave nothing on disk.
        if (isClosed) return await _repository.discard(pages: pages);

        safeEmit(progress(i));
        final processed = await _repository.process(
          raws[i],
          maxBytes: maxBytes,
          metadata: metadata.valueOrNull,
          writeMetadata: options.embedMetadata,
          stamp: stamp,
          onStage: (stage) => safeEmit(progress(i, stage)),
        );
        final page = processed.valueOrNull;
        if (page == null) return await _fail(processed.failureOrNull!, pages);
        pages.add(page);
      }

      if (isClosed) return await _repository.discard(pages: pages);
      await _repository.clearCache();
      safeEmit(FcScanSuccess(FcScanResult(List.unmodifiable(pages))));
    } catch (error) {
      // Platform calls inside the resolver can throw; never strand the UI.
      await _fail(UnknownFailure('Scan failed unexpectedly: $error'), pages);
    }
  }

  /// Ends in an error state; for failures raised outside the cubit.
  void fail(FcCameraFailure failure) => safeEmit(FcScanError(failure));

  Future<void> _fail(
    FcCameraFailure failure, [
    List<FcScannedPage> produced = const [],
  ]) async {
    try {
      await _repository.discard(pages: produced);
    } catch (_) {
      // Cleanup is best effort; the error state below must still land.
    }
    safeEmit(FcScanError(failure));
  }
}
