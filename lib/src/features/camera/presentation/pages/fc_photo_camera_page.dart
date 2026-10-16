import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/fc_navigator.dart';
import '../../../../core/ui/fc_ui.dart';
import '../../../../core/utils/fc_result.dart';
import '../../data/datasources/fc_live_camera.dart';
import '../../domain/entities/fc_camera_frame.dart';
import '../cubits/fc_camera/fc_camera_cubit.dart';
import '../cubits/fc_camera/fc_camera_state.dart';
import '../cubits/fc_photo_review/fc_photo_review_cubit.dart';
import '../cubits/fc_photo_review/fc_photo_review_state.dart';
import '../widgets/fc_camera_error_view.dart';
import '../widgets/fc_camera_preview.dart';
import '../widgets/fc_camera_shutter.dart';
import '../widgets/fc_crop_editor_view.dart';
import '../widgets/fc_photo_review_view.dart';
import '../widgets/fc_resolved_image.dart';

/// In-app camera: live preview, review, crop; pops an `FcReviewedPhoto`.
/// Stays in-process so Android can't kill the host app while shooting.
class FcPhotoCameraPage extends StatelessWidget {
  const FcPhotoCameraPage({this.camera, this.imageFor, super.key});

  final FcLiveCamera? camera;

  final ImageProvider Function(XFile photo)? imageFor;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final cubit = FcCameraCubit(
              camera: camera,
              lens: FcCameraLens.back,
              resolution: FcCameraResolution.photo,
              useAnyLens: true,
            );
            unawaited(cubit.start());
            return cubit;
          },
        ),
        BlocProvider(create: (_) => FcPhotoReviewCubit()),
      ],
      child: _FollowScreenOrientation(
        child: _PhotoCameraView(
          imageFor: imageFor ?? (photo) => FileImage(File(photo.path)),
        ),
      ),
    );
  }
}

class _PhotoCameraView extends StatelessWidget {
  const _PhotoCameraView({required this.imageFor});

  final ImageProvider Function(XFile photo) imageFor;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FcPhotoReviewCubit, FcPhotoReview?>(
      buildWhen: (previous, current) =>
          previous?.photo != current?.photo ||
          previous?.editing != current?.editing,
      builder: (context, review) => PopScope(
        canPop: review == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // Back steps out one level: editor to review, review to retake.
          final cubit = context.read<FcPhotoReviewCubit>();
          if (cubit.state?.editing ?? false) {
            cubit.cancelEditor();
          } else {
            unawaited(cubit.retake());
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: review == null
              ? const _Live()
              // Shared by both screens so switching never re-reads the file.
              : FcResolvedImage(
                  image: imageFor(review.photo),
                  builder: (context, status) {
                    final image = imageFor(review.photo);
                    final size = status.size;
                    return review.editing && size != null
                        ? FcCropEditorView(image: image, size: size)
                        : FcPhotoReviewView(image: image, status: status);
                  },
                ),
        ),
      ),
    );
  }
}

class _Live extends StatelessWidget {
  const _Live();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FcCameraCubit>();

    return Stack(
      fit: StackFit.expand,
      children: [
        BlocBuilder<FcCameraCubit, FcCameraState>(
          buildWhen: (previous, current) => !_sameCamera(previous, current),
          builder: (context, state) => switch (state) {
            FcCameraReady(:final sensorAspect) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (_) => cubit.beginZoom(),
              onScaleUpdate: (details) {
                if (details.pointerCount < 2) return;
                unawaited(cubit.zoomBy(details.scale));
              },
              child: FcCameraPreview(
                camera: cubit.camera,
                sensorAspect: sensorAspect,
              ),
            ),
            FcCameraError(:final failure) => SafeArea(
              child: FcCameraErrorView(failure: failure, onRetry: cubit.start),
            ),
            FcCameraStarting() || FcCameraPaused() => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          },
        ),
        SafeArea(
          child: BlocBuilder<FcCameraCubit, FcCameraState>(
            builder: (context, state) => state is FcCameraReady
                ? _Controls(state: state)
                : const _CloseButton(),
          ),
        ),
      ],
    );
  }

  static bool _sameCamera(FcCameraState previous, FcCameraState current) =>
      previous is FcCameraReady &&
      current is FcCameraReady &&
      previous.lens == current.lens &&
      previous.sensorAspect == current.sensorAspect;
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FcCloseButton(onPressed: () => FcNavigator.close(context)),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state});

  final FcCameraReady state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FcCameraCubit>();
    final idle = !state.capturing;
    final flash = state.flash;

    return Stack(
      children: [
        const _CloseButton(),
        if (flash != null)
          Positioned(
            right: 12,
            top: 12,
            child: _RoundButton(
              icon: switch (flash) {
                FcFlashMode.auto => Icons.flash_auto_rounded,
                FcFlashMode.on => Icons.flash_on_rounded,
                FcFlashMode.off => Icons.flash_off_rounded,
              },
              label: 'Flash ${flash.name}',
              onPressed: idle ? cubit.cycleFlash : null,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Keeps the shutter centred.
              const SizedBox.square(dimension: _RoundButton.size),
              Stack(
                alignment: Alignment.center,
                children: [
                  FcCameraShutter(
                    onPressed: idle ? () => _shoot(context) : null,
                  ),
                  if (!idle)
                    const SizedBox.square(
                      dimension: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
              if (state.canSwitchLens)
                _RoundButton(
                  icon: Icons.cameraswitch_rounded,
                  label: 'Switch camera',
                  onPressed: idle ? cubit.switchLens : null,
                )
              else
                const SizedBox.square(dimension: _RoundButton.size),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _shoot(BuildContext context) async {
    unawaited(HapticFeedback.mediumImpact());
    // Stamp the press time, not when the file lands.
    final takenAt = DateTime.now();
    final result = await context.read<FcCameraCubit>().capture();
    if (!context.mounted) return;

    result.when(
      success: (photo) =>
          context.read<FcPhotoReviewCubit>().review(photo, takenAt: takenAt),
      failure: (_) => ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Could not take the photo. Try again.')),
        ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  static const double size = 52;

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      icon: Icon(icon),
      iconSize: 26,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(size),
        backgroundColor: const Color(0x66000000),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0x33000000),
        disabledForegroundColor: const Color(0x80FFFFFF),
      ),
    );
  }
}

/// Locks capture to the screen orientation so photos match the preview.
class _FollowScreenOrientation extends StatefulWidget {
  const _FollowScreenOrientation({required this.child});

  final Widget child;

  @override
  State<_FollowScreenOrientation> createState() =>
      _FollowScreenOrientationState();
}

class _FollowScreenOrientationState extends State<_FollowScreenOrientation> {
  bool? _landscape;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape == _landscape) return;
    _landscape = landscape;
    unawaited(
      context.read<FcCameraCubit>().syncOrientation(landscape: landscape),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
