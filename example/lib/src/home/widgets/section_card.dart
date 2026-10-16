import 'package:flutter/material.dart';

/// Labelled section on a rounded surface, styled like the kit's own sheets.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.label,
    required this.child,
    this.trailing,
    super.key,
  });

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Tinted icon square used across the demo.
class TintedIcon extends StatelessWidget {
  const TintedIcon({required this.icon, this.color, this.size = 40, super.key});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.5, color: tint),
    );
  }
}
