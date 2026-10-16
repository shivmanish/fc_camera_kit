import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/fc_face_frame_geometry.dart';
import '../../domain/entities/fc_face_frame_status.dart';

/// Fixed status colours; a host theme must never recolour them.
const _red = Color(0xFFEF4444);
const _green = Color(0xFF22C55E);

class FcFaceRing extends StatefulWidget {
  const FcFaceRing({required this.tone, this.countdown, super.key});

  final FcFaceFrameTone tone;

  /// Ring fills over this; the photo auto-captures when it closes.
  final Duration? countdown;

  @override
  State<FcFaceRing> createState() => _FcFaceRingState();
}

class _FcFaceRingState extends State<FcFaceRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(FcFaceRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tone != widget.tone) _syncSpin();
  }

  void _syncSpin() {
    if (widget.tone == FcFaceFrameTone.working) {
      _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.tone) {
    FcFaceFrameTone.searching || FcFaceFrameTone.failed => _red,
    FcFaceFrameTone.ready || FcFaceFrameTone.done => _green,
    FcFaceFrameTone.working => Colors.white,
  };

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;

    return RepaintBoundary(
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: _color),
        duration: const Duration(milliseconds: 200),
        builder: (context, color, _) => TweenAnimationBuilder<double>(
          // Green sweeps in; with auto-capture it spans the countdown.
          key: ValueKey(tone == FcFaceFrameTone.ready),
          tween: Tween(begin: tone == FcFaceFrameTone.ready ? 0 : 1, end: 1),
          duration: widget.countdown ?? const Duration(milliseconds: 350),
          curve: widget.countdown == null ? Curves.easeOutCubic : Curves.linear,
          builder: (context, sweep, _) => CustomPaint(
            size: Size.infinite,
            painter: _RingPainter(
              color: color ?? _color,
              sweep: sweep,
              spin: tone == FcFaceFrameTone.working ? _spin : null,
            ),
            child: _Badge(tone: tone),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.sweep, this.spin})
    : super(repaint: spin);

  final Color color;

  /// Fraction of the circle, 0–1.
  final double sweep;

  final Animation<double>? spin;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = FcFaceFrameGeometry.ovalFor(size).inflate(6);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(rect, stroke..color = const Color(0x40FFFFFF));

    final spinning = spin;
    if (spinning != null) {
      canvas.drawArc(
        rect,
        spinning.value * 2 * pi - pi / 2,
        pi / 2,
        false,
        stroke..color = color,
      );
      return;
    }
    canvas.drawArc(rect, -pi / 2, sweep * 2 * pi, false, stroke..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.sweep != sweep ||
      oldDelegate.spin != spin;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.tone});

  final FcFaceFrameTone tone;

  @override
  Widget build(BuildContext context) {
    final (IconData? icon, Color color) = switch (tone) {
      FcFaceFrameTone.done => (Icons.check_rounded, _green),
      FcFaceFrameTone.failed => (Icons.close_rounded, _red),
      _ => (null, _red),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final circle = FcFaceFrameGeometry.ovalFor(constraints.biggest);
        return Stack(
          children: [
            Positioned(
              left: circle.center.dx - 22,
              top: circle.bottom - 16,
              child: AnimatedScale(
                scale: icon == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(icon ?? Icons.check_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
