import 'package:flutter/material.dart';

import '../../../../presentation/molecules/fc_step_list.dart';
import '../../domain/entities/fc_face_frame_status.dart';

/// What sits under the circle: the message, a detail line, the steps of a
/// running job, and the buttons once a flow has stopped.
class FcFaceFramePanel extends StatelessWidget {
  const FcFaceFramePanel({
    required this.status,
    required this.onAction,
    super.key,
  });

  final FcFaceFrameStatus status;
  final ValueChanged<FcFaceFrameAction> onAction;

  static const _fade = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detail = status.detail;
    final primary = status.primaryAction;
    final secondary = status.secondaryAction;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: _fade,
          child: Semantics(
            key: ValueKey(status.messageId),
            liveRegion: true,
            child: Text(
              status.message,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(blurRadius: 8)],
              ),
            ),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xB3FFFFFF),
            ),
          ),
        ],
        if (status.steps.isNotEmpty) ...[
          const SizedBox(height: 16),
          FcStepList(labels: status.steps, current: status.currentStep),
        ],
        if (primary != null) ...[
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => onAction(FcFaceFrameAction.primary),
            style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
            child: Text(primary),
          ),
        ],
        if (secondary != null)
          TextButton(
            onPressed: () => onAction(FcFaceFrameAction.secondary),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 48),
            ),
            child: Text(secondary),
          ),
      ],
    );
  }
}
