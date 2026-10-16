import 'package:flutter/material.dart';

import '../permissions/fc_permission_type.dart';

/// Shared sheet and dialog styling; colours always come from the host theme.
abstract final class FcUi {
  static const double sheetRadius = 28;
  static const double dialogRadius = 28;
  static const double cardRadius = 16;
  static const double buttonRadius = 14;
  static const double buttonHeight = 54;
  static const double gutter = 24;

  static IconData iconFor(FcPermissionType type) => switch (type) {
    FcPermissionType.camera => Icons.photo_camera_rounded,
    FcPermissionType.location => Icons.location_on_rounded,
  };
}

class FcIconBadge extends StatelessWidget {
  const FcIconBadge({
    required this.icon,
    this.size = 56,
    this.color,
    this.subdued = false,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color? color;

  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: subdued ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        icon,
        size: size * 0.46,
        color: subdued ? tint.withValues(alpha: 0.55) : tint,
      ),
    );
  }
}

class FcPrimaryButton extends StatelessWidget {
  const FcPrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: FcUi.buttonHeight,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FcUi.buttonRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          // Stay filled while busy; the grey disabled look reads as broken.
          disabledBackgroundColor: busy
              ? scheme.primary.withValues(alpha: 0.75)
              : null,
          disabledForegroundColor: busy ? scheme.onPrimary : null,
        ),
        child: busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: scheme.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class FcSheetGrabber extends StatelessWidget {
  const FcSheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class FcCloseButton extends StatelessWidget {
  const FcCloseButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Close',
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              Icons.close_rounded,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
