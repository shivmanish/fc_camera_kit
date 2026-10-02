import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/fc_navigator.dart';
import '../../../../core/permissions/fc_permission_type.dart';
import '../../../../core/permissions/fc_permissions.dart';
import '../../../../core/ui/fc_ui.dart';
import '../cubit/fc_permission_cubit.dart';
import '../cubit/fc_permission_state.dart';

/// Shown when permission is granted but the device location toggle is off.
///
/// Separate from the permission sheet because the fix is different: no
/// permission dialog can turn GPS back on, only device settings can.
class FcLocationServiceDialog extends StatelessWidget {
  const FcLocationServiceDialog({
    this.allowCancel = true,
    this.permissions,
    super.key,
  });

  final bool allowCancel;

  /// Injected gateway. Tests pass a fake so no platform channel is touched.
  @visibleForTesting
  final FcPermissions? permissions;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FcPermissionCubit(
        required: const {FcPermissionType.location},
        permissions: permissions,
      ),
      child: _DialogView(allowCancel: allowCancel),
    );
  }
}

class _DialogView extends StatelessWidget {
  const _DialogView({required this.allowCancel});

  final bool allowCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      // Fires on the transition into "read, and enabled". Testing only
      // `!previous.serviceEnabled` would never fire when the toggle was
      // already on before this opened, trapping the user behind canPop:false.
      child: BlocListener<FcPermissionCubit, FcPermissionState>(
        listenWhen: (previous, current) =>
            current.loaded &&
            current.serviceEnabled &&
            !(previous.loaded && previous.serviceEnabled),
        listener: (context, _) {
          FcNavigator.close(context, true);
        },
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FcUi.dialogRadius),
          ),
          // Overlaid in the corner so it adds no vertical space of its own.
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _Badge(),
                    const SizedBox(height: 22),
                    Text(
                      'Turn on location',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Location access is allowed, but location services are '
                      'switched off on this device — so the photo cannot record '
                      'where it was taken.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _Steps(),
                    const SizedBox(height: 22),
                    const _EnableButton(),
                  ],
                ),
              ),
              if (allowCancel)
                Positioned(
                  top: 8,
                  right: 8,
                  child: FcCloseButton(
                    onPressed: () => FcNavigator.close(context, false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reads as "permission fine, location off" at a glance.
class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 76,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const FcIconBadge(icon: Icons.location_off_rounded, size: 62),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_rounded, size: 20, color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// Says exactly what will happen, so leaving the app is not a surprise.
class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(FcUi.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            for (final (index, step) in const [
              'Open device location settings',
              'Switch location on',
              'Come back — this closes by itself',
            ].indexed) ...[
              if (index > 0) const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnableButton extends StatelessWidget {
  const _EnableButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FcPermissionCubit, FcPermissionState>(
      buildWhen: (previous, current) => previous.busy != current.busy,
      builder: (context, state) => FcPrimaryButton(
        label: 'Open location settings',
        busy: state.busy,
        onPressed: context.read<FcPermissionCubit>().openLocationSettings,
      ),
    );
  }
}
