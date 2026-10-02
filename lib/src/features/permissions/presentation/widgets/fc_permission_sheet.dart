import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/navigation/fc_navigator.dart';
import '../../../../core/permissions/fc_permission_status.dart';
import '../../../../core/permissions/fc_permission_type.dart';
import '../../../../core/permissions/fc_permissions.dart';
import '../../../../core/ui/fc_ui.dart';
import '../cubit/fc_permission_cubit.dart';
import '../cubit/fc_permission_state.dart';

/// Non-dismissible sheet listing the permissions still blocking a capture.
class FcPermissionSheet extends StatelessWidget {
  const FcPermissionSheet({
    required this.required,
    this.allowCancel = true,
    this.permissions,
    super.key,
  });

  final Set<FcPermissionType> required;

  /// Shows an explicit "Not now". The sheet is never dismissible by tapping
  /// outside, dragging, or the back gesture regardless of this flag.
  final bool allowCancel;

  /// Injected gateway. Production leaves this null and the cubit uses the
  /// singleton; tests pass a fake so no platform channel is touched.
  @visibleForTesting
  final FcPermissions? permissions;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          FcPermissionCubit(required: required, permissions: permissions),
      child: _SheetView(allowCancel: allowCancel),
    );
  }
}

class _SheetView extends StatelessWidget {
  const _SheetView({required this.allowCancel});

  final bool allowCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      // Pops itself the moment everything is granted, including when the user
      // fixes it in App Settings and comes back.
      child: BlocListener<FcPermissionCubit, FcPermissionState>(
        listenWhen: (previous, current) =>
            !previous.allGranted && current.allGranted,
        listener: (context, _) {
          FcNavigator.close(context, true);
        },
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            // Stacked, not stacked in a row: the close button overlays the
            // corner so it cannot push the title down or add spacing of its
            // own. The Column alone decides the sheet's height.
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FcSheetGrabber(),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          FcUi.gutter,
                          10,
                          FcUi.gutter,
                          FcUi.gutter,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FcIconBadge(
                              icon: Icons.lock_rounded,
                              size: 58,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Permissions needed',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const _Subtitle(),
                            const SizedBox(height: 24),
                            const _PermissionCard(),
                            const SizedBox(height: 24),
                            const _ContinueButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
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
      ),
    );
  }
}

/// Copy changes once the only remaining fix is App Settings.
class _Subtitle extends StatelessWidget {
  const _Subtitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<FcPermissionCubit, FcPermissionState>(
      buildWhen: (previous, current) =>
          previous.needsAppSettings != current.needsAppSettings,
      builder: (context, state) => Text(
        state.needsAppSettings
            ? 'Some access was turned off. Enable it in Settings to continue.'
            : 'To capture a verified photo, the app needs the following '
                  'access.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<FcPermissionCubit, FcPermissionState>(
      buildWhen: (previous, current) => previous.statuses != current.statuses,
      builder: (context, state) {
        // Driven by the required set, not the status map, so the card renders
        // complete on the first frame instead of flashing empty while the
        // first status read is still in flight.
        final types = state.ordered;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(FcUi.cardRadius),
          ),
          child: Column(
            children: [
              for (var i = 0; i < types.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 16,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                _PermissionRow(
                  type: types[i],
                  status: state.statuses[types[i]],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FcPermissionCubit, FcPermissionState>(
      buildWhen: (previous, current) =>
          previous.busy != current.busy ||
          previous.needsAppSettings != current.needsAppSettings,
      builder: (context, state) {
        final cubit = context.read<FcPermissionCubit>();

        return FcPrimaryButton(
          label: state.needsAppSettings ? 'Open Settings' : 'Continue',
          busy: state.busy,
          onPressed: state.needsAppSettings
              ? cubit.openAppSettings
              : cubit.requestAll,
        );
      },
    );
  }
}

/// One permission line: what it is, why it is needed, whether it is satisfied.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.type, required this.status});

  final FcPermissionType type;
  final FcPermissionStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final granted = status?.isUsable ?? false;
    final blocked = status?.needsAppSettings ?? false;

    // Without this a blocked row looks identical to a merely-denied one, so on
    // a mixed result the user cannot tell which permission needs Settings.
    final trailing = switch ((granted, blocked)) {
      (true, _) => (Icons.check_circle_rounded, scheme.tertiary, 'Allowed'),
      (false, true) => (Icons.error_rounded, scheme.error, 'Blocked'),
      (false, false) => (
        Icons.circle_outlined,
        scheme.outlineVariant.withValues(alpha: 0.9),
        'Not allowed',
      ),
    };

    return Semantics(
      label: '${type.label}. ${trailing.$3}. ${type.reason}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            FcIconBadge(
              icon: FcUi.iconFor(type),
              size: 40,
              subdued: granted,
              color: granted ? scheme.tertiary : scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    blocked ? 'Blocked — enable in Settings' : type.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: blocked ? scheme.error : scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(trailing.$1, size: 22, color: trailing.$2),
          ],
        ),
      ),
    );
  }
}
