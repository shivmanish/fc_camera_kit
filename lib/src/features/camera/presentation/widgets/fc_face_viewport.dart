import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/fc_face_frame_geometry.dart';

class FcFaceViewport extends StatelessWidget {
  const FcFaceViewport({
    required this.preview,
    this.frozenImagePath,
    this.mirrorFrozen = true,
    super.key,
  });

  final Widget preview;

  final String? frozenImagePath;

  /// Flip the unmirrored photo so it doesn't jump from the mirrored preview.
  final bool mirrorFrozen;

  @override
  Widget build(BuildContext context) {
    final frozen = frozenImagePath;
    final size = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (frozen == null)
          RepaintBoundary(child: preview)
        else
          Transform.flip(
            flipX: mirrorFrozen,
            child: Image.file(
              File(frozen),
              fit: BoxFit.cover,
              cacheWidth: (size.width * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        const RepaintBoundary(
          child: CustomPaint(painter: _ScrimPainter(), size: Size.infinite),
        ),
      ],
    );
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(FcFaceFrameGeometry.ovalFor(size)),
    );
    canvas.drawPath(scrim, Paint()..color = const Color(0xB3000000));
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => false;
}
