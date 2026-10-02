import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home_cubit.dart';
import '../home_state.dart';
import 'section_card.dart';
import 'user_sheet.dart';

/// The "who" half of the stamp: whatever `FcCameraKit.setUser` was last given.
class IdentityCard extends StatelessWidget {
  const IdentityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) => previous.user != current.user,
      builder: (context, state) {
        final user = state.user;

        return SectionCard(
          label: 'Signed in as',
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                TintedIcon(
                  icon: user == null
                      ? Icons.person_off_outlined
                      : Icons.person_rounded,
                  color: user == null ? scheme.outline : scheme.primary,
                  size: 46,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'No user set',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.id ?? 'The stamp will omit who took the photo',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => showUserSheet(context, current: user),
                  child: Text(user == null ? 'Set' : 'Change'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
