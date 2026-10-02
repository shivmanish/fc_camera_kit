import 'package:flutter/material.dart';

/// Every step of a long job, listed up front so the wait has a visible end.
///
/// Drawn for a dark backdrop: the kit's processing screens sit over a photo.
class FcStepList extends StatelessWidget {
  const FcStepList({required this.labels, required this.current, super.key});

  final List<String> labels;

  /// Index of the running step; earlier ones are done, later ones waiting.
  final int current;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++)
            _StepRow(
              label: labels[i],
              status: switch (i) {
                _ when i < current => _StepStatus.done,
                _ when i == current => _StepStatus.active,
                _ => _StepStatus.waiting,
              },
            ),
        ],
      ),
    );
  }
}

enum _StepStatus { done, active, waiting }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.status});

  final String label;
  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, FontWeight weight) = switch (status) {
      _StepStatus.done => (const Color(0xCCFFFFFF), FontWeight.w500),
      _StepStatus.active => (Colors.white, FontWeight.w600),
      _StepStatus.waiting => (const Color(0x61FFFFFF), FontWeight.w500),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(width: 22, height: 22, child: _Indicator(status: status)),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: weight,
                letterSpacing: -0.1,
              ),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.status});

  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      _StepStatus.done => const Icon(
        Icons.check_circle_rounded,
        size: 21,
        color: Color(0xFF4ADE80),
      ),
      // A spinner rather than an icon: only the running step should move.
      _StepStatus.active => const Padding(
        padding: EdgeInsets.all(2),
        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
      ),
      _StepStatus.waiting => const Icon(
        Icons.circle_outlined,
        size: 19,
        color: Color(0x4DFFFFFF),
      ),
    };
  }
}
