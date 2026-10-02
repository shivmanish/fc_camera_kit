import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home_cubit.dart';
import '../home_state.dart';
import 'section_card.dart';

/// Switches where the stamp is drawn, so both variants can be compared on the
/// same photo without an app restart.
class StampCard extends StatelessWidget {
  const StampCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<HomeCubit, HomeState>(
      buildWhen: (previous, current) =>
          previous.placement != current.placement ||
          previous.stampScans != current.stampScans,
      builder: (context, state) {
        return SectionCard(
          label: 'Stamp placement',
          trailing: _StampScansSwitch(
            value: state.stampScans,
            onChanged: context.read<HomeCubit>().setStampScans,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<StampPlacement>(
                    segments: const [
                      ButtonSegment(
                        value: StampPlacement.overlay,
                        icon: Icon(Icons.layers_rounded, size: 18),
                        label: Text('Overlay'),
                      ),
                      ButtonSegment(
                        value: StampPlacement.extend,
                        icon: Icon(Icons.expand_rounded, size: 18),
                        label: Text('Extend'),
                      ),
                    ],
                    selected: {state.placement},
                    onSelectionChanged: (selection) =>
                        context.read<HomeCubit>().setPlacement(selection.first),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  switch (state.placement) {
                    StampPlacement.overlay =>
                      'Frosted strip drawn on the photo. Aspect ratio kept, '
                          'the strip covers the bottom of the image.',
                    StampPlacement.extend =>
                      'Solid panel added below the photo. Nothing is covered, '
                          'the image gets taller.',
                  },
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
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

/// Photos are always stamped; scans only when this is on.
class _StampScansSwitch extends StatelessWidget {
  const _StampScansSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Stamp scans & selfies',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        // Scaled so the header row keeps its height.
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
