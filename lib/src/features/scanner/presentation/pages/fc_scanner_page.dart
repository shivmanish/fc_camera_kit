import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/fc_camera_kit.dart';
import '../../../../core/config/fc_scan_options.dart';
import '../../../../core/error/fc_camera_failure.dart';
import '../../../../core/image/metadata/fc_photo_metadata.dart';
import '../../../../core/navigation/fc_navigator.dart';
import '../../../../core/permissions/fc_location_permission.dart';
import '../../../../core/permissions/fc_permission_type.dart';
import '../../../../core/utils/fc_result.dart';
import '../../../permissions/presentation/fc_permission_gate.dart';
import '../../../stamping/fc_stamp_style.dart';
import '../../domain/entities/fc_scan_result.dart';
import '../../domain/entities/fc_scan_stamp.dart';
import '../../domain/repositories/fc_scan_repository.dart';
import '../cubits/fc_scan/fc_scan_cubit.dart';
import '../cubits/fc_scan/fc_scan_state.dart';
import '../widgets/fc_scan_error_view.dart';
import '../widgets/fc_scan_finished_view.dart';
import '../widgets/fc_scan_preparing_view.dart';

/// Opens the document scanner and turns the pages into finished files.
///
/// The page always closes itself when the scan ends and pops with the
/// [FcScanResult], or `null` otherwise. Callbacks only notify; exactly one of
/// them fires per scan.
class FcScannerPage extends StatelessWidget {
  const FcScannerPage({
    this.maxPages,
    this.source,
    this.enhancement,
    this.embedMetadata,
    this.maxBytes,
    this.stamp,
    this.placement,
    this.dateFormat,
    this.style = const FcStampStyle(),
    this.onCompleted,
    this.onCancelled,
    this.onFailed,
    this.repository,
    super.key,
  });

  /// Overrides for this scan; anything left `null` comes from `init()`.
  final int? maxPages;
  final FcScanSource? source;
  final FcScanEnhancement? enhancement;
  final bool? embedMetadata;
  final int? maxBytes;

  /// Stamp settings, as in `capture()`; `null` ones come from `init()`.
  final bool? stamp;
  final StampPlacement? placement;
  final String? dateFormat;
  final FcStampStyle style;

  final ValueChanged<FcScanResult>? onCompleted;

  /// Also fires when the user closes the page after an error.
  final VoidCallback? onCancelled;

  /// When `null`, the page shows the error with a retry instead.
  final ValueChanged<FcCameraFailure>? onFailed;

  final FcScanRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FcScanCubit(repository: repository),
      child: _ScannerFlow(page: this),
    );
  }
}

class _ScannerFlow extends StatefulWidget {
  const _ScannerFlow({required this.page});

  final FcScannerPage page;

  @override
  State<_ScannerFlow> createState() => _ScannerFlowState();
}

class _ScannerFlowState extends State<_ScannerFlow> {
  FcScannerPage get _page => widget.page;

  bool _starting = false;
  bool _notified = false;

  /// The scan ended but this route is the navigator's first and can't close.
  bool _stranded = false;

  /// Last progress shown; stays up unchanged until the route closes.
  FcScanProcessing? _lastProgress;

  @override
  void initState() {
    super.initState();
    // After the first frame, so this route is underneath when the scanner closes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final cubit = context.read<FcScanCubit>();
    if (_starting || cubit.isBusy) return;

    _starting = true;
    try {
      await _run(cubit);
    } catch (error) {
      cubit.fail(UnknownFailure('Scan could not start: $error'));
    } finally {
      _starting = false;
    }
  }

  Future<void> _run(FcScanCubit cubit) async {
    final kit = FcCameraKit.instance;
    if (!kit.isInitialized) {
      return cubit.fail(
        const ConfigurationFailure(
          'FcCameraKit.instance.init() must be called before scan().',
        ),
      );
    }

    final maxPages = _page.maxPages ?? kit.scanOptions.maxPages;
    if (maxPages <= 0) {
      return cubit.fail(
        const ConfigurationFailure('maxPages must be positive.'),
      );
    }

    final options = kit.scanOptions.copyWith(
      maxPages: maxPages,
      source: _page.source,
      enhancement: _page.enhancement,
      embedMetadata: _page.embedMetadata,
      stamp: _page.stamp,
    );

    final needsMetadata = options.embedMetadata || options.stamp;
    final needsLocation = needsMetadata && kit.requireLocation;
    if (needsLocation) {
      final granted = await FcPermissionGate.ensure(
        context,
        required: const {FcPermissionType.location},
      );
      if (!mounted) return;
      if (!granted) {
        return cubit.fail(
          const PermissionFailure(
            'Location access was not granted.',
            permission: 'location',
            permanentlyDenied: false,
          ),
        );
      }
    }

    await cubit.start(
      options: options,
      maxBytes: _page.maxBytes ?? kit.maxBytes,
      resolveMetadata: () =>
          _resolveMetadata(needed: needsMetadata, withLocation: needsLocation),
      stamp: options.stamp
          ? FcScanStamp(
              placement: _page.placement ?? kit.placement,
              dateFormat: _page.dateFormat ?? kit.dateFormat,
              includeDevice: kit.includeDeviceInStamp,
              style: _page.style,
            )
          : null,
    );
  }

  Future<FcResult<FcPhotoMetadata?>> _resolveMetadata({
    required bool needed,
    required bool withLocation,
  }) async {
    if (!needed) return fcSuccess(null);

    final kit = FcCameraKit.instance;
    if (!withLocation) return fcSuccess(kit.buildMetadata());

    // The gate already cleared permission; never prompt twice.
    final location = await FcLocationPermission.instance.getCurrentLocation(
      resolveAddress: true,
      requestIfNeeded: false,
    );
    return location.fold(
      fcFailure<FcPhotoMetadata?>,
      (fix) => fcSuccess(kit.buildMetadata(location: fix)),
    );
  }

  void _onState(BuildContext context, FcScanState state) {
    if (state is FcScanProcessing) _lastProgress = state;
    if (state is FcScanScanning) _lastProgress = null;
    switch (state) {
      case FcScanSuccess(:final result):
        _finish(() => _page.onCompleted?.call(result), result);
      case FcScanError(failure: CancelledFailure()):
        _finish(() => _page.onCancelled?.call(), null);
      case FcScanError(:final failure):
        final onFailed = _page.onFailed;
        // Without a handler the error view stays up and offers a retry.
        if (onFailed != null) _finish(() => onFailed(failure), null);
      case FcScanIdle() || FcScanScanning() || FcScanProcessing():
        break;
    }
  }

  /// Notifies once, then closes this route unless the callback already did.
  void _finish(VoidCallback notify, FcScanResult? result) {
    _notifyOnce(notify);
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _close(result))
      ..ensureVisualUpdate();
  }

  void _notifyOnce(VoidCallback notify) {
    if (_notified) return;
    _notified = true;
    notify();
  }

  void _close(FcScanResult? result) {
    if (!mounted || FcNavigator.close(context, result)) return;
    // Still on screen but uncloseable: the navigator's first route.
    if (ModalRoute.of(context)?.isActive ?? false) {
      setState(() => _stranded = true);
    }
  }

  @override
  void dispose() {
    // Torn down from outside (e.g. pushAndRemoveUntil): still report once.
    // Deferred, so host code never runs while the tree is being finalised.
    final onCancelled = _page.onCancelled;
    if (!_notified && onCancelled != null) scheduleMicrotask(onCancelled);
    _notified = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FcScanCubit, FcScanState>(
      listener: _onState,
      builder: (context, state) => PopScope(
        // Leaving mid-processing would strand half-written files.
        canPop: state is! FcScanProcessing,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _notifyOnce(() => _page.onCancelled?.call());
        },
        child: Scaffold(
          // Dark while scanning and preparing; themed for error and finished.
          backgroundColor: _stranded || _showsError(state)
              ? null
              : Colors.black,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _bodyFor(state),
          ),
        ),
      ),
    );
  }

  bool _showsError(FcScanState state) =>
      state is FcScanError &&
      state.failure is! CancelledFailure &&
      _page.onFailed == null;

  Widget _bodyFor(FcScanState state) {
    if (_stranded) {
      return SafeArea(
        child: FcScanFinishedView(completed: state is FcScanSuccess),
      );
    }
    if (state is FcScanError && _showsError(state)) {
      return SafeArea(
        child: FcScanErrorView(
          failure: state.failure,
          onRetry: _start,
          onClose: () => _finish(() => _page.onCancelled?.call(), null),
        ),
      );
    }

    // One key for the whole flow: never swapped, so it never reads as a new
    // screen; it only updates its image and text. Ending states keep the last
    // page up until the route has closed.
    final progress = switch (state) {
      FcScanProcessing() => state,
      FcScanSuccess() || FcScanError() => _lastProgress,
      FcScanIdle() || FcScanScanning() => null,
    };
    return FcScanPreparingView(
      key: const ValueKey('fc-scan-preparing'),
      imagePath: progress?.preview.path,
      page: progress?.page,
      total: progress?.total,
      stages: progress?.stages ?? const [],
      stage: progress?.stage,
    );
  }
}
