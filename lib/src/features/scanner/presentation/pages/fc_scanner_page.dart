import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/fc_camera_kit.dart';
import '../../../../core/config/fc_scan_options.dart';
import '../../../../core/error/fc_camera_failure.dart';
import '../../../../core/image/stamp/fc_stamp_style.dart';
import '../../../../core/navigation/fc_flow_reporter.dart';
import '../../../../core/navigation/fc_navigator.dart';
import '../../../../core/permissions/fc_permission_type.dart';
import '../../../../presentation/molecules/fc_flow_finished_view.dart';
import '../../../permissions/presentation/fc_permission_gate.dart';
import '../../domain/entities/fc_scan_result.dart';
import '../../domain/repositories/fc_scan_repository.dart';
import '../cubits/fc_scanner_screen/fc_scanner_screen_cubit.dart';
import '../cubits/fc_scanner_screen/fc_scanner_screen_state.dart';
import '../widgets/fc_scan_error_view.dart';
import '../widgets/fc_scan_preparing_view.dart';

/// Document scanner screen; pops with the [FcScanResult], or `null`.
/// Exactly one callback fires per scan.
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

  /// `null` values fall back to `init()`.
  final int? maxPages;
  final FcScanSource? source;
  final FcScanEnhancement? enhancement;
  final bool? embedMetadata;
  final int? maxBytes;

  final bool? stamp;
  final StampPlacement? placement;
  final String? dateFormat;
  final FcStampStyle style;

  final ValueChanged<FcScanResult>? onCompleted;

  /// Also fires when the user closes after an error.
  final VoidCallback? onCancelled;

  /// If `null`, the error is shown with a retry.
  final ValueChanged<FcCameraFailure>? onFailed;

  final FcScanRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FcScannerScreenCubit(
        reporter: FcFlowReporter(
          onCompleted: onCompleted,
          onCancelled: onCancelled,
          onFailed: onFailed,
        ),
        maxPages: maxPages,
        source: source,
        enhancement: enhancement,
        embedMetadata: embedMetadata,
        maxBytes: maxBytes,
        stamp: stamp,
        placement: placement,
        dateFormat: dateFormat,
        style: style,
        repository: repository,
      )..start(),
      child: const _ScannerView(),
    );
  }
}

class _ScannerView extends StatelessWidget {
  const _ScannerView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FcScannerScreenCubit, FcScannerScreenState>(
      listener: _onState,
      builder: (context, state) {
        final cubit = context.read<FcScannerScreenCubit>();
        final themed = state is FcScannerFailed || state is FcScannerStranded;
        return PopScope(
          // Blocks back while files are mid-write.
          canPop: state is! FcScannerActive || state.canPop,
          onPopInvokedWithResult: (didPop, _) =>
              cubit.systemBack(didPop: didPop),
          child: Scaffold(
            backgroundColor: themed ? null : Colors.black,
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _body(cubit, state),
            ),
          ),
        );
      },
    );
  }

  static Widget _body(FcScannerScreenCubit cubit, FcScannerScreenState state) {
    final progress = switch (state) {
      FcScannerActive(:final progress) => progress,
      FcScannerLeaving(:final progress) => progress,
      _ => null,
    };
    return switch (state) {
      FcScannerStranded(:final completed) => SafeArea(
        child: FcFlowFinishedView(
          completed: completed,
          completedLabel: 'Scan complete',
        ),
      ),
      FcScannerFailed(:final failure) => SafeArea(
        child: FcScanErrorView(
          failure: failure,
          onRetry: cubit.retry,
          onClose: cubit.cancel,
        ),
      ),
      // One stable key, so the flow never looks like a new screen.
      _ => FcScanPreparingView(
        key: const ValueKey('fc-scan-preparing'),
        imagePath: progress?.preview.path,
        page: progress?.page,
        total: progress?.total,
        stages: progress?.stages ?? const [],
        stage: progress?.stage,
      ),
    };
  }

  static void _onState(BuildContext context, FcScannerScreenState state) {
    switch (state) {
      case FcScannerAskingPermission(:final required):
        _askPermission(context, required);
      case FcScannerLeaving(:final result):
        _closeRoute(context, result);
      case FcScannerPreparing() ||
          FcScannerActive() ||
          FcScannerFailed() ||
          FcScannerStranded():
        break;
    }
  }

  static Future<void> _askPermission(
    BuildContext context,
    Set<FcPermissionType> required,
  ) async {
    final granted = await FcPermissionGate.ensure(context, required: required);
    if (context.mounted) {
      await context.read<FcScannerScreenCubit>().permissionResolved(
        granted: granted,
      );
    }
  }

  /// Deferred a frame so a host callback that navigated wins.
  static void _closeRoute(BuildContext context, FcScanResult? result) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!context.mounted || FcNavigator.close(context, result)) return;
        context.read<FcScannerScreenCubit>().routeNotClosed(
          stillShown: ModalRoute.of(context)?.isActive ?? false,
        );
      })
      ..ensureVisualUpdate();
  }
}
