import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../../../../../core/config/fc_camera_kit.dart';
import '../../../../../core/config/fc_cubit.dart';
import '../../../../../core/config/fc_scan_options.dart';
import '../../../../../core/error/fc_camera_failure.dart';
import '../../../../../core/image/metadata/fc_photo_metadata.dart';
import '../../../../../core/image/stamp/fc_stamp_style.dart';
import '../../../../../core/navigation/fc_flow_reporter.dart';
import '../../../../../core/permissions/fc_location_permission.dart';
import '../../../../../core/permissions/fc_permission_type.dart';
import '../../../../../core/utils/fc_result.dart';
import '../../../domain/entities/fc_scan_result.dart';
import '../../../domain/entities/fc_scan_stamp.dart';
import '../../../domain/repositories/fc_scan_repository.dart';
import '../fc_scan/fc_scan_cubit.dart';
import '../fc_scan/fc_scan_state.dart';
import 'fc_scanner_screen_state.dart';

/// Runs the scanner screen: settings, the location permission, the scan,
/// retries, and the single outcome.
///
/// Owns the scan cubit and closes it with itself.
class FcScannerScreenCubit
    extends FcCubit<FcScannerScreenState, FcScanResult, void> {
  FcScannerScreenCubit({
    required FcFlowReporter<FcScanResult> reporter,
    this.maxPages,
    this.source,
    this.enhancement,
    this.embedMetadata,
    this.maxBytes,
    this.stamp,
    this.placement,
    this.dateFormat,
    this.style = const FcStampStyle(),
    FcScanRepository? repository,
  }) : _reporter = reporter,
       _scan = FcScanCubit(repository: repository),
       super(initialState: const FcScannerPreparing()) {
    _subscription = _scan.stream.listen(_onScan);
  }

  final int? maxPages;
  final FcScanSource? source;
  final FcScanEnhancement? enhancement;
  final bool? embedMetadata;
  final int? maxBytes;
  final bool? stamp;
  final StampPlacement? placement;
  final String? dateFormat;
  final FcStampStyle style;

  final FcFlowReporter<FcScanResult> _reporter;
  final FcScanCubit _scan;
  late final StreamSubscription<FcScanState> _subscription;

  late FcScanOptions _options;
  late int _maxBytes;
  late bool _needsLocation;
  FcScanProcessing? _progress;
  bool _starting = false;

  /// After the first frame, so this route is underneath when the platform
  /// scanner closes, and the screen is listening for permission requests.
  Future<void> start() async {
    await SchedulerBinding.instance.endOfFrame;
    await _begin();
  }

  Future<void> retry() => _begin();

  Future<void> permissionResolved({required bool granted}) async {
    if (isClosed || state is! FcScannerAskingPermission) return;
    if (!granted) {
      return _failed(
        const PermissionFailure(
          'Location access was not granted.',
          permission: 'location',
          permanentlyDenied: false,
        ),
      );
    }
    await _run();
  }

  /// Close on the error view.
  void cancel() {
    _reporter.cancelled();
    safeEmit(FcScannerLeaving(progress: _progress));
  }

  /// A system back that did close the route is a cancel.
  void systemBack({required bool didPop}) {
    if (didPop) _reporter.cancelled();
  }

  /// The route didn't close; [stillShown] when it is still on screen.
  void routeNotClosed({required bool stillShown}) {
    if (!stillShown || isClosed) return;
    final leaving = state;
    safeEmit(
      FcScannerStranded(
        completed: leaving is FcScannerLeaving && leaving.result != null,
      ),
    );
  }

  Future<void> _begin() async {
    if (isClosed || _starting || _scan.isBusy) return;
    _starting = true;
    try {
      final failure = _configure();
      if (failure != null) return _failed(failure);

      if (_needsLocation) {
        safeEmit(const FcScannerAskingPermission({FcPermissionType.location}));
        return;
      }
      await _run();
    } catch (error) {
      _failed(UnknownFailure('Scan could not start: $error'));
    } finally {
      _starting = false;
    }
  }

  FcCameraFailure? _configure() {
    final kit = FcCameraKit.instance;
    if (!kit.isInitialized) {
      return const ConfigurationFailure(
        'FcCameraKit.instance.init() must be called before scan().',
      );
    }

    final pages = maxPages ?? kit.scanOptions.maxPages;
    if (pages <= 0) {
      return const ConfigurationFailure('maxPages must be positive.');
    }
    _maxBytes = maxBytes ?? kit.maxBytes;
    if (_maxBytes <= 0) {
      return const ConfigurationFailure('maxBytes must be positive.');
    }

    _options = kit.scanOptions.copyWith(
      maxPages: pages,
      source: source,
      enhancement: enhancement,
      embedMetadata: embedMetadata,
      stamp: stamp,
    );
    _needsLocation =
        (_options.embedMetadata || _options.stamp) && kit.requireLocation;
    return null;
  }

  Future<void> _run() async {
    final kit = FcCameraKit.instance;
    _progress = null;
    safeEmit(FcScannerActive(_scan.state));
    await _scan.start(
      options: _options,
      maxBytes: _maxBytes,
      resolveMetadata: _resolveMetadata,
      stamp: _options.stamp
          ? FcScanStamp(
              placement: placement ?? kit.placement,
              dateFormat: dateFormat ?? kit.dateFormat,
              includeDevice: kit.includeDeviceInStamp,
              style: style,
            )
          : null,
    );
  }

  Future<FcResult<FcPhotoMetadata?>> _resolveMetadata() async {
    if (!_options.embedMetadata && !_options.stamp) return fcSuccess(null);

    final kit = FcCameraKit.instance;
    if (!_needsLocation) return fcSuccess(kit.buildMetadata());

    // Permission was already cleared; never prompt twice.
    final location = await FcLocationPermission.instance.getCurrentLocation(
      resolveAddress: true,
      requestIfNeeded: false,
    );
    return location.fold(
      fcFailure<FcPhotoMetadata?>,
      (fix) => fcSuccess(kit.buildMetadata(location: fix)),
    );
  }

  void _onScan(FcScanState scan) {
    if (isClosed || state is FcScannerLeaving || state is FcScannerStranded) {
      return;
    }
    switch (scan) {
      case FcScanProcessing():
        _progress = scan;
        safeEmit(FcScannerActive(scan, progress: scan));
      case FcScanSuccess(:final result):
        _reporter.completed(result);
        safeEmit(FcScannerLeaving(result: result, progress: _progress));
      case FcScanError(failure: CancelledFailure()):
        _reporter.cancelled();
        safeEmit(FcScannerLeaving(progress: _progress));
      case FcScanError(:final failure):
        _failed(failure);
      case FcScanIdle() || FcScanScanning():
        safeEmit(FcScannerActive(scan, progress: _progress));
    }
  }

  /// The host takes the failure when it can; otherwise the screen offers a
  /// retry.
  void _failed(FcCameraFailure failure) {
    if (_reporter.handlesFailures) {
      _reporter.failed(failure);
      safeEmit(FcScannerLeaving(progress: _progress));
    } else {
      safeEmit(FcScannerFailed(failure));
    }
  }

  @override
  Future<void> close() async {
    // Report first: the host hears the screen went the moment it goes.
    _reporter.dispose();
    await Future.wait([_subscription.cancel(), _scan.close()]);
    return super.close();
  }
}
