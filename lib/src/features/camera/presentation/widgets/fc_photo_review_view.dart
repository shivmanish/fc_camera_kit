import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/fc_navigator.dart';
import '../../../../core/ui/fc_ui.dart';
import '../cubits/fc_photo_review/fc_photo_review_cubit.dart';
import '../cubits/fc_photo_review/fc_photo_review_state.dart';
import 'fc_camera_tool_button.dart';
import 'fc_edited_photo.dart';
import 'fc_resolved_image.dart';

/// The shot, as it will be used: pinch or double-tap to check it is sharp,
/// then Retake, Crop or Use photo.
///
/// Use photo is the one filled button and sits under the right thumb: the
/// common path is a single tap. Retake and Crop are quieter, and Crop marks
/// itself once the photo is edited.
class FcPhotoReviewView extends StatelessWidget {
  const FcPhotoReviewView({
    required this.image,
    required this.status,
    super.key,
  });

  final ImageProvider image;
  final FcImageStatus status;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                BlocBuilder<FcPhotoReviewCubit, FcPhotoReview?>(
                  buildWhen: (previous, current) =>
                      previous?.edit != current?.edit,
                  builder: (context, review) =>
                      _Photo(image: image, status: status, review: review),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FcCloseButton(
                      onPressed: () => FcNavigator.close(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _Actions(canEdit: status.size != null),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.image,
    required this.status,
    required this.review,
  });

  final ImageProvider image;
  final FcImageStatus status;
  final FcPhotoReview? review;

  @override
  Widget build(BuildContext context) {
    final size = status.size;
    final review = this.review;

    if (status.failed) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
            SizedBox(height: 12),
            Text(
              "Can't show this photo",
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      );
    }
    if (size == null || review == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return _Zoomable(
      // A new edit is a new picture: start it unzoomed.
      key: ValueKey(review.edit),
      child: FcEditedPhoto(image: image, size: size, edit: review.edit),
    );
  }
}

/// Pinch to zoom, or double-tap to jump to 2.5× where tapped and back.
class _Zoomable extends StatefulWidget {
  const _Zoomable({required this.child, super.key});

  final Widget child;

  @override
  State<_Zoomable> createState() => _ZoomableState();
}

class _ZoomableState extends State<_Zoomable>
    with SingleTickerProviderStateMixin {
  static const _doubleTapScale = 2.5;

  final _transform = TransformationController();
  // Created up front: a lazy one would first be built in dispose(), where the
  // ticker can no longer look up its TickerMode.
  late final AnimationController _animation;
  Animation<Matrix4>? _tween;
  Offset _tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_step);
  }

  void _step() {
    final tween = _tween;
    if (tween != null) _transform.value = tween.value;
  }

  void _toggle() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    final end = zoomed
        ? Matrix4.identity()
        : (Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1)
            ..setTranslationRaw(
              -_tapAt.dx * (_doubleTapScale - 1),
              -_tapAt.dy * (_doubleTapScale - 1),
              0,
            ));
    _tween = Matrix4Tween(
      begin: _transform.value,
      end: end,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic));
    unawaited(_animation.forward(from: 0));
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _tapAt = details.localPosition,
      onDoubleTap: _toggle,
      child: InteractiveViewer(
        transformationController: _transform,
        maxScale: 5,
        child: SizedBox.expand(child: Center(child: widget.child)),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.canEdit});

  /// The photo's size is known, so the editor can lay out its frame.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final review = context.read<FcPhotoReviewCubit>();
    final edited = context.select(
      (FcPhotoReviewCubit cubit) => !(cubit.state?.edit.isNone ?? true),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The stamp isn't on this preview; say so, so nobody retakes
          // looking for it.
          const Text(
            'The stamp is added when you use the photo',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FcCameraToolButton(
                icon: Icons.refresh_rounded,
                label: 'Retake',
                onPressed: review.retake,
              ),
              FcCameraToolButton(
                icon: Icons.crop_rotate_rounded,
                label: 'Crop',
                active: edited,
                onPressed: canEdit ? review.openEditor : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => FcNavigator.close(context, review.accept()),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use photo'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, FcUi.buttonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FcUi.buttonRadius),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
