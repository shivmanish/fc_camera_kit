import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home_cubit.dart';
import '../home_state.dart';
import 'image_strip_card.dart';

/// Session photos, newest first; images only, as the stamp holds the details.
class CaptureCard extends StatelessWidget {
  const CaptureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<HomeCubit, HomeState, List<FcCaptureResult>>(
      selector: (state) => state.captures,
      builder: (context, captures) => ImageStripCard(
        label: 'Captures',
        viewerTitle: 'Stamped photo',
        paths: [for (final capture in captures) capture.file.path],
      ),
    );
  }
}
