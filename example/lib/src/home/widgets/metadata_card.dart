import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../home_cubit.dart';
import '../home_state.dart';
import 'section_card.dart';

/// Exactly what the Phase 6 stamper will receive — the point of the package,
/// visible before any pixels exist.
class MetadataCard extends StatelessWidget {
  const MetadataCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) => previous.metadata != current.metadata,
      builder: (context, state) {
        final meta = state.metadata;
        if (meta == null) return const SizedBox.shrink();

        return SectionCard(
          label: 'Stamp preview',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Line(
                  icon: Icons.person_outline_rounded,
                  value: meta.hasUser
                      ? '${meta.userName} · ${meta.userId}'
                      : null,
                  missing: 'No user set',
                ),
                const SizedBox(height: 10),
                _Line(
                  icon: Icons.schedule_rounded,
                  value: DateFormat(
                    FcCameraKit.instance.dateFormat,
                  ).format(meta.capturedAt),
                ),
                const SizedBox(height: 10),
                _Line(
                  icon: Icons.place_outlined,
                  value: meta.location?.address ?? meta.location?.coordinates,
                  missing: 'No location',
                ),
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Burned into the pixels and written to EXIF.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, this.value, this.missing});

  final IconData icon;
  final String? value;
  final String? missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final present = value != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: present ? scheme.onSurfaceVariant : scheme.outline,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value ?? missing ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: present ? scheme.onSurface : scheme.outline,
              fontStyle: present ? FontStyle.normal : FontStyle.italic,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
