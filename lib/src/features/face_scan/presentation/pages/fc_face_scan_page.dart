import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/fc_camera_kit.dart';
import '../../../../core/error/fc_camera_failure.dart';
import '../../../../core/image/stamp/fc_stamp_style.dart';
import '../../../../core/navigation/fc_flow_reporter.dart';
import '../../../../core/navigation/fc_navigator.dart';
import '../../../../core/permissions/fc_permission_type.dart';
import '../../../../presentation/molecules/fc_flow_finished_view.dart';
import '../../../camera/data/datasources/fc_frame_snapshot.dart';
import '../../../camera/data/datasources/fc_live_camera.dart';
import '../../../camera/domain/entities/fc_face_frame_status.dart';
import '../../../camera/presentation/pages/fc_face_camera_page.dart';
import '../../../permissions/presentation/fc_permission_gate.dart';
import '../../domain/entities/fc_face_result.dart';
import '../../domain/repositories/fc_face_detector.dart';
import '../../domain/repositories/fc_face_repository.dart';
import '../cubits/fc_face_scan_screen/fc_face_scan_screen_cubit.dart';
import '../cubits/fc_face_scan_screen/fc_face_scan_screen_state.dart';

/// Asks for the permissions a scan needs; `true` when all are granted.
typedef FcPermissionEnsurer =
    Future<bool> Function(BuildContext context, Set<FcPermissionType> required);

/// Frames the user's face, checks for a blink, takes the selfie and turns it
/// into an [FcFaceResult].
///
/// The page closes itself when the flow ends and pops with the result, or
/// `null` otherwise. Exactly one callback fires per scan.
class FcFaceScanPage extends StatelessWidget {
  const FcFaceScanPage({
    this.blinks,
    this.maxBytes,
    this.embedMetadata,
    this.stamp,
    this.placement,
    this.dateFormat,
    this.style = const FcStampStyle(),
    this.autoCaptureAfter,
    this.mirrorSelfie,
    this.onCompleted,
    this.onCancelled,
    this.onFailed,
    this.camera,
    this.detector,
    this.repository,
    super.key,
  });

  /// Overrides for this scan; anything left `null` comes from `init()`.
  final int? blinks;
  final int? maxBytes;
  final bool? embedMetadata;

  /// Stamp settings, as in `capture()` and `scan()`.
  final bool? stamp;
  final StampPlacement? placement;
  final String? dateFormat;
  final FcStampStyle style;

  /// Green this long takes the photo by itself; `Duration.zero` leaves it to
  /// the shutter button.
  final Duration? autoCaptureAfter;

  /// Saves the selfie as seen in the mirrored preview.
  final bool? mirrorSelfie;

  final ValueChanged<FcFaceResult>? onCompleted;

  /// Also fires when the user closes the page.
  final VoidCallback? onCancelled;

  /// Fires when the user closes the page after a failure; without it, a
  /// failure is reported as a cancel.
  final ValueChanged<FcCameraFailure>? onFailed;

  /// Test seams: the device camera, ML Kit and the file pipeline.
  final FcLiveCamera? camera;
  final FcFaceDetector? detector;
  final FcFaceRepository? repository;

  /// Replaces the permission sheet in tests.
  @visibleForTesting
  static FcPermissionEnsurer? debugPermissionGate;

  /// Replaces saving the camera frame as a photo in tests.
  @visibleForTesting
  static FcFrameSaver? debugSaveFrame;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FcFaceScanScreenCubit(
        reporter: FcFlowReporter(
          onCompleted: onCompleted,
          onCancelled: onCancelled,
          onFailed: onFailed,
        ),
        blinks: blinks,
        maxBytes: maxBytes,
        embedMetadata: embedMetadata,
        stamp: stamp,
        placement: placement,
        dateFormat: dateFormat,
        style: style,
        autoCaptureAfter: autoCaptureAfter,
        mirrorSelfie: mirrorSelfie,
        saveFrame: debugSaveFrame,
        camera: camera,
        detector: detector,
        repository: repository,
      )..start(),
      child: const _FaceScanView(),
    );
  }
}

class _FaceScanView extends StatelessWidget {
  const _FaceScanView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FcFaceScanScreenCubit, FcFaceScanScreenState>(
      listener: _onState,
      builder: (context, state) {
        final cubit = context.read<FcFaceScanScreenCubit>();
        return PopScope(
          // Leaving mid-processing would strand half-written files.
          canPop: state is! FcFaceScanActive || state.canPop,
          onPopInvokedWithResult: (didPop, _) =>
              cubit.systemBack(didPop: didPop),
          child: _body(cubit, state),
        );
      },
    );
  }

  static Widget _body(
    FcFaceScanScreenCubit cubit,
    FcFaceScanScreenState state,
  ) {
    if (state is FcFaceScanStranded) {
      return Scaffold(
        body: SafeArea(
          child: FcFlowFinishedView(
            completed: state.completed,
            completedLabel: 'Face scan complete',
          ),
        ),
      );
    }

    final camera = cubit.camera;
    final status = switch (state) {
      FcFaceScanActive(:final status) => status,
      FcFaceScanLeaving(:final status) => status,
      _ => null,
    };
    if (camera == null || status == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tell the cubit the size the oval is drawn for; it ignores repeats.
        final size = constraints.biggest;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => cubit.layoutChanged(size),
        );
        return FcFaceCameraPage(
          camera: camera,
          status: status,
          onShutter: cubit.shutter,
          onAction: cubit.action,
          onClose: cubit.cancel,
        );
      },
    );
  }

  static void _onState(BuildContext context, FcFaceScanScreenState state) {
    switch (state) {
      case FcFaceScanAskingPermission(:final required):
        _askPermission(context, required);
      case FcFaceScanLeaving(:final result):
        _closeRoute(context, result);
      case FcFaceScanActive(:final status)
          when status.tone == FcFaceFrameTone.ready:
        HapticFeedback.selectionClick();
      case FcFaceScanActive() || FcFaceScanPreparing() || FcFaceScanStranded():
        break;
    }
  }

  static Future<void> _askPermission(
    BuildContext context,
    Set<FcPermissionType> required,
  ) async {
    final gate =
        FcFaceScanPage.debugPermissionGate ??
        (context, required) =>
            FcPermissionGate.ensure(context, required: required);
    final granted = await gate(context, required);
    if (context.mounted) {
      await context.read<FcFaceScanScreenCubit>().permissionResolved(
        granted: granted,
      );
    }
  }

  /// On the next frame, so a host callback that already navigated wins.
  static void _closeRoute(BuildContext context, FcFaceResult? result) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (!context.mounted || FcNavigator.close(context, result)) return;
        context.read<FcFaceScanScreenCubit>().routeNotClosed(
          stillShown: ModalRoute.of(context)?.isActive ?? false,
        );
      })
      ..ensureVisualUpdate();
  }
}
