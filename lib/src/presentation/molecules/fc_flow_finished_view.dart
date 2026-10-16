import 'package:flutter/material.dart';

import '../../core/ui/fc_ui.dart';

/// Shown only when a flow page is the first route and can't close.
class FcFlowFinishedView extends StatelessWidget {
  const FcFlowFinishedView({
    required this.completed,
    this.completedLabel = 'Complete',
    super.key,
  });

  final bool completed;
  final String completedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FcIconBadge(
            icon: completed ? Icons.check_rounded : Icons.close_rounded,
            subdued: !completed,
          ),
          const SizedBox(height: 16),
          Text(
            completed ? completedLabel : 'Closed',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
