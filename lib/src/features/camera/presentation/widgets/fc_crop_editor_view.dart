import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/image/edit/fc_crop_geometry.dart';
import '../cubits/fc_photo_review/fc_photo_review_cubit.dart';
import '../cubits/fc_photo_review/fc_photo_review_state.dart';
import 'fc_camera_tool_button.dart';

/// Crop and rotate, laid out the way phone photo editors are: Cancel and Done
/// at the top, the photo with its frame in the middle, shapes and tools under
/// the thumbs. Nothing is cut until the photo is stamped.
class FcCropEditorView extends StatelessWidget {
  const FcCropEditorView({required this.image, required this.size, super.key});

  final ImageProvider image;

  /// The upright photo's size, in pixels.
  final Size size;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<FcPhotoReviewCubit, FcPhotoReview?>(
        builder: (context, review) {
          final draft = review?.draft;
          if (draft == null) return const SizedBox.shrink();

          return Column(
            children: [
              const _TopBar(),
              Expanded(
                child: _CropCanvas(image: image, size: size, draft: draft),
              ),
              _Shapes(selected: draft.aspect, size: size),
              _Tools(pristine: draft.isPristine),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final review = context.read<FcPhotoReviewCubit>();

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          TextButton(
            onPressed: review.cancelEditor,
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
          const Expanded(
            child: Text(
              'Crop & rotate',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: review.applyEditor,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The turned photo with its frame. Drag a corner or edge to resize, or the
/// middle to move; the thirds grid shows only while dragging.
class _CropCanvas extends StatefulWidget {
  const _CropCanvas({
    required this.image,
    required this.size,
    required this.draft,
  });

  final ImageProvider image;
  final Size size;
  final FcPhotoDraft draft;

  @override
  State<_CropCanvas> createState() => _CropCanvasState();
}

class _CropCanvasState extends State<_CropCanvas> {
  /// Room around the photo so a corner on its edge is still easy to grab.
  static const _margin = 28.0;

  /// How far from a corner or edge a touch still grabs it.
  static const _reach = 28.0;

  FcCropHandle? _handle;

  @override
  Widget build(BuildContext context) {
    final edit = widget.draft.edit;
    final free = widget.draft.aspect == FcCropAspect.free;

    return LayoutBuilder(
      builder: (context, constraints) {
        final room = (Offset.zero & constraints.biggest).deflate(_margin);
        final turned = edit.turn(widget.size);
        final scale = math.min(
          room.width / turned.width,
          room.height / turned.height,
        );
        final photo = Rect.fromCenter(
          center: room.center,
          width: turned.width * scale,
          height: turned.height * scale,
        );
        final frame = Rect.fromLTRB(
          photo.left + edit.crop.left * photo.width,
          photo.top + edit.crop.top * photo.height,
          photo.left + edit.crop.right * photo.width,
          photo.top + edit.crop.bottom * photo.height,
        );

        return Semantics(
          label: 'Crop frame. Drag a corner to resize, or the middle to move.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => setState(
              () => _handle = _handleAt(details.localPosition, frame, free),
            ),
            onPanUpdate: (details) {
              final handle = _handle;
              if (handle == null) return;
              context.read<FcPhotoReviewCubit>().dragCrop(
                handle,
                Offset(
                  details.delta.dx / photo.width,
                  details.delta.dy / photo.height,
                ),
                widget.size,
              );
            },
            onPanEnd: (_) => setState(() => _handle = null),
            onPanCancel: () => setState(() => _handle = null),
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: photo,
                  child: RotatedBox(
                    quarterTurns: edit.quarterTurns,
                    child: Image(
                      image: widget.image,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FramePainter(
                      frame: frame,
                      grid: _handle != null,
                      edges: free,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Corners win over edges, edges over the inside, so a frame shrunk small
  /// can still be grown again.
  static FcCropHandle? _handleAt(Offset at, Rect frame, bool edges) {
    final corners = {
      FcCropHandle.topLeft: frame.topLeft,
      FcCropHandle.topRight: frame.topRight,
      FcCropHandle.bottomRight: frame.bottomRight,
      FcCropHandle.bottomLeft: frame.bottomLeft,
    };
    FcCropHandle? nearest;
    var best = _reach;
    for (final MapEntry(key: handle, value: corner) in corners.entries) {
      final distance = (corner - at).distance;
      if (distance <= best) {
        best = distance;
        nearest = handle;
      }
    }
    if (nearest != null) return nearest;

    if (edges) {
      final alongX = at.dx > frame.left && at.dx < frame.right;
      final alongY = at.dy > frame.top && at.dy < frame.bottom;
      if (alongY && (at.dx - frame.left).abs() <= _reach) {
        return FcCropHandle.left;
      }
      if (alongY && (at.dx - frame.right).abs() <= _reach) {
        return FcCropHandle.right;
      }
      if (alongX && (at.dy - frame.top).abs() <= _reach) {
        return FcCropHandle.top;
      }
      if (alongX && (at.dy - frame.bottom).abs() <= _reach) {
        return FcCropHandle.bottom;
      }
    }
    return frame.contains(at) ? FcCropHandle.inside : null;
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({
    required this.frame,
    required this.grid,
    required this.edges,
  });

  final Rect frame;
  final bool grid;
  final bool edges;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything outside the frame dims, so what is kept reads at a glance.
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(frame),
      Paint()..color = const Color(0xB3000000),
    );

    if (grid) {
      final line = Paint()
        ..color = const Color(0x80FFFFFF)
        ..strokeWidth = 1;
      for (var i = 1; i < 3; i++) {
        final x = frame.left + frame.width * i / 3;
        final y = frame.top + frame.height * i / 3;
        canvas
          ..drawLine(Offset(x, frame.top), Offset(x, frame.bottom), line)
          ..drawLine(Offset(frame.left, y), Offset(frame.right, y), line);
      }
    }

    canvas.drawRect(
      frame,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final handle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    final arm = math.min(22.0, math.min(frame.width, frame.height) / 3);
    for (final (corner, dx, dy) in [
      (frame.topLeft, 1.0, 1.0),
      (frame.topRight, -1.0, 1.0),
      (frame.bottomRight, -1.0, -1.0),
      (frame.bottomLeft, 1.0, -1.0),
    ]) {
      canvas
        ..drawLine(corner, corner.translate(dx * arm, 0), handle)
        ..drawLine(corner, corner.translate(0, dy * arm), handle);
    }

    if (edges) {
      final half = arm / 2;
      final mid = frame.center;
      canvas
        ..drawLine(
          Offset(mid.dx - half, frame.top),
          Offset(mid.dx + half, frame.top),
          handle,
        )
        ..drawLine(
          Offset(mid.dx - half, frame.bottom),
          Offset(mid.dx + half, frame.bottom),
          handle,
        )
        ..drawLine(
          Offset(frame.left, mid.dy - half),
          Offset(frame.left, mid.dy + half),
          handle,
        )
        ..drawLine(
          Offset(frame.right, mid.dy - half),
          Offset(frame.right, mid.dy + half),
          handle,
        );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.frame != frame || old.grid != grid || old.edges != edges;
}

class _Shapes extends StatelessWidget {
  const _Shapes({required this.selected, required this.size});

  final FcCropAspect selected;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final review = context.read<FcPhotoReviewCubit>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (final (aspect, icon, label) in const [
            (FcCropAspect.free, Icons.crop_free_rounded, 'Free'),
            (FcCropAspect.original, Icons.crop_original_rounded, 'Original'),
            (FcCropAspect.square, Icons.crop_square_rounded, 'Square'),
          ])
            _ShapeChip(
              icon: icon,
              label: label,
              selected: aspect == selected,
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                review.chooseAspect(aspect, size);
              },
            ),
        ],
      ),
    );
  }
}

/// A pill drawn by hand rather than a `ChoiceChip`: a host's chip theme would
/// otherwise repaint it, and on this always-dark screen that can leave the
/// text the same colour as its background.
class _ShapeChip extends StatelessWidget {
  const _ShapeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.black : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? Colors.white : const Color(0x1FFFFFFF),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? Colors.white : const Color(0x66FFFFFF),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({required this.pristine});

  final bool pristine;

  @override
  Widget build(BuildContext context) {
    final review = context.read<FcPhotoReviewCubit>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FcCameraToolButton(
          icon: Icons.rotate_90_degrees_ccw_rounded,
          label: 'Rotate',
          onPressed: () {
            unawaited(HapticFeedback.selectionClick());
            review.rotateLeft();
          },
        ),
        FcCameraToolButton(
          icon: Icons.restart_alt_rounded,
          label: 'Reset',
          onPressed: pristine ? null : review.resetDraft,
        ),
      ],
    );
  }
}
