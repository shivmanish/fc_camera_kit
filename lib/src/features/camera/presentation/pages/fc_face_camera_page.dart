import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/fc_ui.dart';
import '../../domain/entities/fc_face_frame_geometry.dart';
import '../../domain/entities/fc_face_frame_status.dart';
import '../cubits/fc_camera/fc_camera_cubit.dart';
import '../cubits/fc_camera/fc_camera_state.dart';
import '../widgets/fc_camera_error_view.dart';
import '../widgets/fc_camera_preview.dart';
import '../widgets/fc_camera_shutter.dart';
import '../widgets/fc_face_frame_panel.dart';
import '../widgets/fc_face_ring.dart';
import '../widgets/fc_face_viewport.dart';

/// The face-detection frame: front camera inside a circle with a status ring,
/// one hint, and a shutter.
///
/// Purely visual. It knows nothing about faces: the owner runs [camera] and
/// decides everything shown through [status].
class FcFaceCameraPage extends StatelessWidget {
  const FcFaceCameraPage({
    required this.camera,
    required this.status,
    required this.onShutter,
    required this.onClose,
    this.onAction,
    super.key,
  });

  final FcCameraCubit camera;
  final FcFaceFrameStatus status;
  final VoidCallback onShutter;
  final VoidCallback onClose;
  final ValueChanged<FcFaceFrameAction>? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Always dark: a camera surface, whatever the host theme.
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          BlocBuilder<FcCameraCubit, FcCameraState>(
            bloc: camera,
            builder: (context, state) => switch (state) {
              // A frozen photo, the steps or the outcome don't need the
              // camera: keep them up while it is released or reopening.
              _ when !status.isLive => _Frame(
                status: status,
                preview: const SizedBox.shrink(),
                onShutter: onShutter,
                onAction: onAction,
              ),
              FcCameraReady(:final sensorAspect) => _Frame(
                status: status,
                preview: FcCameraPreview(
                  camera: camera.camera,
                  sensorAspect: sensorAspect,
                ),
                onShutter: onShutter,
                onAction: onAction,
              ),
              FcCameraError(:final failure) => SafeArea(
                child: FcCameraErrorView(
                  failure: failure,
                  onRetry: camera.start,
                ),
              ),
              FcCameraStarting() || FcCameraPaused() => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FcCloseButton(onPressed: onClose),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The live frame: viewport, ring, panel and shutter, laid out around the
/// oval so nothing overlaps on any screen: controls below the oval in
/// portrait, beside it in landscape.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.status,
    required this.preview,
    required this.onShutter,
    required this.onAction,
  });

  final FcFaceFrameStatus status;
  final Widget preview;
  final VoidCallback onShutter;
  final ValueChanged<FcFaceFrameAction>? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final oval = FcFaceFrameGeometry.ovalFor(size);
        final padding = MediaQuery.paddingOf(context);
        final panel = FcFaceFramePanel(
          status: status,
          onAction: (action) => onAction?.call(action),
        );
        final shutter = _Shutter(status: status, onShutter: onShutter);

        return Stack(
          fit: StackFit.expand,
          children: [
            FcFaceViewport(
              preview: preview,
              frozenImagePath: status.frozenImagePath,
              mirrorFrozen: !status.frozenMirrored,
            ),
            FcFaceRing(tone: status.tone, countdown: status.countdown),
            if (size.width > size.height)
              Positioned(
                left: oval.right + 32,
                right: padding.right + 24,
                top: padding.top + 24,
                bottom: padding.bottom + 24,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: SingleChildScrollView(child: panel)),
                    if (status.showsShutter) ...[
                      const SizedBox(height: 24),
                      shutter,
                    ],
                  ],
                ),
              )
            else ...[
              Positioned(
                left: 24,
                right: 24,
                top: oval.bottom + 40,
                // The shutter's room is only kept while it's on screen.
                bottom: padding.bottom + (status.showsShutter ? 120 : 24),
                child: SingleChildScrollView(child: panel),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: padding.bottom + 32,
                child: Center(child: shutter),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Visible only while live with no buttons offered; enabled only when green.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.status, required this.onShutter});

  final FcFaceFrameStatus status;
  final VoidCallback onShutter;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: status.showsShutter ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !status.showsShutter,
        child: FcCameraShutter(
          onPressed: status.shutterEnabled ? onShutter : null,
        ),
      ),
    );
  }
}
