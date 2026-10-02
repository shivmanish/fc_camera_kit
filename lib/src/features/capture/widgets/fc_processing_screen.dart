import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/fc_camera_kit.dart';
import '../../../core/error/fc_camera_exception.dart';
import '../../../core/error/fc_camera_failure.dart';
import '../../../core/image/metadata/fc_geo_location.dart';
import '../../../core/image/stamp/fc_stamp_style.dart';
import '../../../core/navigation/fc_navigator.dart';
import '../../../core/permissions/fc_location_permission.dart';
import '../../../core/utils/fc_result.dart';
import '../../../presentation/molecules/fc_step_list.dart';
import '../../stamping/cubit/fc_stamp_cubit.dart';
import '../../stamping/cubit/fc_stamp_state.dart';
import '../fc_capture_result.dart';
import '../fc_capture_source.dart';
import '../fc_image_source.dart';

/// Owns everything from opening the picker to handing back the finished file.
///
/// It is pushed **before** the picker launches, on purpose. `image_picker`
/// hands control to another activity, and whatever sits underneath is what the
/// user sees the instant that activity closes. Pushing afterwards would flash
/// the host app's screen between the camera and this one.
///
/// Pops with an [FcCaptureResult] on success or an [FcCameraFailure] otherwise,
/// so the caller awaits one value.
class FcProcessingScreen extends StatelessWidget {
  const FcProcessingScreen({
    required this.source,
    this.imageSource,
    this.placement,
    this.dateFormat,
    this.maxBytes,
    this.style = const FcStampStyle(),
    super.key,
  });

  final FcCaptureSource source;
  final FcImageSource? imageSource;
  final StampPlacement? placement;
  final String? dateFormat;
  final int? maxBytes;
  final FcStampStyle style;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FcStampCubit(),
      child: _ProcessingView(
        source: source,
        imageSource: imageSource,
        placement: placement,
        dateFormat: dateFormat,
        maxBytes: maxBytes,
        style: style,
      ),
    );
  }
}

/// Stateful to run the sequence once on entry and to hold the picked file.
class _ProcessingView extends StatefulWidget {
  const _ProcessingView({
    required this.source,
    required this.imageSource,
    required this.placement,
    required this.dateFormat,
    required this.maxBytes,
    required this.style,
  });

  final FcCaptureSource source;
  final FcImageSource? imageSource;
  final StampPlacement? placement;
  final String? dateFormat;
  final int? maxBytes;
  final FcStampStyle style;

  @override
  State<_ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends State<_ProcessingView> {
  XFile? _picked;

  @override
  void initState() {
    super.initState();
    // After the first frame, so this route is mounted before the picker
    // activity covers it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final cubit = context.read<FcStampCubit>();
    final kit = FcCameraKit.instance;

    try {
      final picked = await (widget.imageSource ?? FcImageSource()).pick(
        widget.source,
      );
      if (!mounted) return;
      if (picked == null) return _close(const CancelledFailure());

      setState(() => _picked = picked);

      final location = await _resolveLocation(kit);
      if (!mounted) return;
      if (location.isLeft()) return _close(location.failureOrNull!);

      await cubit.process(
        source: picked,
        metadata: kit.buildMetadata(location: location.valueOrNull),
        placement: widget.placement,
        dateFormat: widget.dateFormat,
        maxBytes: widget.maxBytes,
        style: widget.style,
      );
      if (!mounted) return;

      _close(switch (cubit.state) {
        FcStampSuccess(:final result) => result,
        FcStampFailure(:final failure) => failure,
        _ => const UnknownFailure('Processing ended in an unexpected state.'),
      });
    } on FcCameraException catch (error) {
      if (mounted) _close(CameraFailure(error.message));
    } catch (error) {
      if (mounted) _close(UnknownFailure('$error'));
    }
  }

  /// Only fatal because `requireLocation` says so — that flag exists to choose
  /// between no photo and a photo with no location.
  Future<FcResult<FcGeoLocation?>> _resolveLocation(FcCameraKit kit) async {
    if (!kit.requireLocation) return fcSuccess(null);

    // The gate already cleared permission; do not prompt a second time.
    final result = await FcLocationPermission.instance.getCurrentLocation(
      resolveAddress: true,
      requestIfNeeded: false,
    );

    return result.fold(fcFailure<FcGeoLocation?>, fcSuccess<FcGeoLocation?>);
  }

  void _close(Object outcome) => FcNavigator.close(context, outcome);

  @override
  Widget build(BuildContext context) {
    final picked = _picked;

    return PopScope(
      // Leaving mid-pipeline would strand a half-written file.
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Nothing to show until the picker returns; the picker activity is
            // covering this anyway.
            if (picked != null) ...[
              Image.file(
                File(picked.path),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(color: Color(0x99000000)),
              ),
            ],
            if (picked != null) const SafeArea(child: _Progress()),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FcStampCubit, FcStampState>(
      buildWhen: (previous, current) => current is FcStampProcessing,
      builder: (context, state) {
        // Before the first stage lands, show the first step as already running.
        // The pipeline always starts there, so a separate "preparing" title
        // would flash for a few frames and say nothing.
        final stage = state is FcStampProcessing
            ? state.stage
            : FcStampStage.values.first;
        final current = FcStampStage.values.indexOf(stage);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            // Names the running step. Cross-faded, because it changes three
            // times and a hard swap reads as a glitch.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                stage.label,
                key: ValueKey(stage),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Keep the app open',
              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13),
            ),
            const SizedBox(height: 32),
            FcStepList(
              labels: [for (final stage in FcStampStage.values) stage.label],
              current: current,
            ),
          ],
        );
      },
    );
  }
}
