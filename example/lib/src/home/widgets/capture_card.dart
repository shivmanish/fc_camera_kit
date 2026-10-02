import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home_cubit.dart';
import '../home_state.dart';
import 'image_strip_card.dart';

/// Every photo captured this session, newest first.
///
/// Shows only the images: who, when and where are burned into their pixels, so
/// repeating them as text would duplicate the thing the stamp exists to prove.
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
