import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/fc_face_frame_geometry.dart';
import '../../domain/entities/fc_face_frame_status.dart';

/// Fixed on purpose: these are status signals over a camera image, and a host
/// theme must never turn "not ready" green.
const _red = Color(0xFFEF4444);
const _green = Color(0xFF22C55E);

/// The ring around the face circle: red, green, a progress arc, or a tick.
class FcFaceRing extends StatefulWidget {
  const FcFaceRing({required this.tone, this.countdown, super.key});

  final FcFaceFrameTone tone;

  /// When set while ready, the green fills over it: the photo takes itself
  /// when the ring closes.
  final Duration? countdown;

  @override
  State<FcFaceRing> createState() => _FcFaceRingState();
}

/// Stateful only for the spinner controller, which must be disposed.
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
          // Green sweeps in, so the change reads as "locked on"; with
          // auto-capture it fills over the countdown instead.
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

  /// 0–1 of the full circle drawn in [color].
  final double sweep;

  /// When set, a rotating progress arc is drawn instead.
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

/// Tick or cross on the bottom of the ring once a flow has finished.
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
