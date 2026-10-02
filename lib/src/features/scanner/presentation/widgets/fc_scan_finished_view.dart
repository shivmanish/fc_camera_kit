import 'package:flutter/material.dart';

import '../../../../core/ui/fc_ui.dart';

/// Shown only when the scanner page is the first route and can't close.
class FcScanFinishedView extends StatelessWidget {
  const FcScanFinishedView({required this.completed, super.key});

  final bool completed;

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
            completed ? 'Scan complete' : 'Scan closed',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
