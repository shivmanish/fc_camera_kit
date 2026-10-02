import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home_cubit.dart';
import '../home_state.dart';
import 'section_card.dart';

/// The "where" half of the stamp.
class LocationCard extends StatelessWidget {
  const LocationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
          previous.location != current.location ||
          previous.locating != current.locating,
      builder: (context, state) {
        final location = state.location;

        return SectionCard(
          label: 'Location',
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    TintedIcon(
                      icon: location == null
                          ? Icons.location_searching_rounded
                          : Icons.my_location_rounded,
                      color: location == null ? scheme.outline : scheme.primary,
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location?.coordinates ?? 'No fix yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _detail(state),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.tonal(
                    onPressed: state.locating
                        ? null
                        : context.read<HomeCubit>().fetchLocation,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: state.locating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Text(
                            location == null
                                ? 'Get current location'
                                : 'Refresh location',
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

  static String _detail(HomeState state) {
    if (state.locating) return 'Acquiring a fix…';

    final location = state.location;
    if (location == null) return 'Tap below to resolve where you are';

    final parts = <String>[
      if (location.accuracyMeters != null)
        '±${location.accuracyMeters!.round()}m',
      if (location.address != null) location.address!,
    ];
    return parts.isEmpty ? 'Fix acquired' : parts.join(' · ');
  }
}
