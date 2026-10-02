import 'package:flutter/material.dart';

import '../../../core/navigation/fc_navigator.dart';
import '../../../core/ui/fc_ui.dart';
import '../fc_capture_source.dart';

/// Asks where the photo should come from.
///
/// Shown only when the caller does not name a source. Dismissible, unlike the
/// permission sheet — backing out here is a normal choice, not a blocker.
Future<FcCaptureSource?> showSourceSheet(BuildContext context) {
  return FcNavigator.showSheet<FcCaptureSource>(
    context,
    (_) => const _SourceSheet(),
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
  );
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      // The close button overlays the corner so it adds no vertical space.
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FcSheetGrabber(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a photo',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'It will be stamped and compressed before it is returned.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SourceTile(
                      source: FcCaptureSource.camera,
                      icon: Icons.photo_camera_rounded,
                      label: 'Take a photo',
                      detail: 'Uses the device camera',
                    ),
                    const SizedBox(height: 10),
                    const _SourceTile(
                      source: FcCaptureSource.gallery,
                      icon: Icons.photo_library_rounded,
                      label: 'Choose from gallery',
                      detail: 'Pick an existing photo',
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: FcCloseButton(onPressed: () => FcNavigator.close(context)),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.icon,
    required this.label,
    required this.detail,
  });

  final FcCaptureSource source;
  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => FcNavigator.close(context, source),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}
