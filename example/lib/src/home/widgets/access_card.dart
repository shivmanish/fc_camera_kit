import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home_cubit.dart';
import '../home_state.dart';
import 'section_card.dart';

/// Live permission state, plus the one call a host app really makes.
class AccessCard extends StatelessWidget {
  const AccessCard({super.key});

  Future<void> _runGate(BuildContext context) async {
    final cubit = context.read<HomeCubit>();

    // This single call is the whole integration: check, explain, request,
    // recover from a permanent denial, then confirm location services.
    await FcPermissionGate.ensure(context);
    await cubit.refreshAccess();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
          previous.statuses != current.statuses ||
          previous.serviceEnabled != current.serviceEnabled ||
          previous.checkingAccess != current.checkingAccess,
      builder: (context, state) {
        final types = FcPermissionType.values
            .where(FcPermissions.captureDefaults.contains)
            .toList();

        return SectionCard(
          label: 'Access',
          trailing: state.checkingAccess
              ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          child: Column(
            children: [
              for (final type in types)
                _AccessRow(
                  icon: type == FcPermissionType.camera
                      ? Icons.photo_camera_rounded
                      : Icons.location_on_rounded,
                  label: type.label,
                  detail: _describe(state.statuses[type]),
                  ok: state.statuses[type]?.isUsable ?? false,
                ),
              _AccessRow(
                icon: Icons.satellite_alt_rounded,
                label: 'Location services',
                detail: state.serviceEnabled
                    ? 'On'
                    : 'Off — the device toggle, not a permission',
                ok: state.serviceEnabled,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.tonal(
                    onPressed: () => _runGate(context),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      state.ready ? 'Re-check access' : 'Grant access',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _describe(FcPermissionStatus? status) => switch (status) {
    null => 'Not checked',
    FcPermissionStatus.granted => 'Allowed',
    FcPermissionStatus.grantedReduced => 'Allowed, approximate only',
    FcPermissionStatus.denied => 'Not allowed yet',
    FcPermissionStatus.deniedForever => 'Blocked — needs Settings',
  };
}

class _AccessRow extends StatelessWidget {
  const _AccessRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label: '$label. $detail',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            TintedIcon(
              icon: icon,
              color: ok ? scheme.tertiary : scheme.primary,
              size: 38,
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 1),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              ok ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 21,
              color: ok
                  ? scheme.tertiary
                  : scheme.outlineVariant.withValues(alpha: 0.9),
            ),
          ],
        ),
      ),
    );
  }
}
