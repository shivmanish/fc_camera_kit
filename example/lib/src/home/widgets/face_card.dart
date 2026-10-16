import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home_cubit.dart';
import '../home_state.dart';
import 'image_strip_card.dart';

/// Every face scan this session, newest first.
class FaceCard extends StatelessWidget {
  const FaceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<HomeCubit, HomeState, List<FcFaceResult>>(
      selector: (state) => state.faces,
      builder: (context, faces) => ImageStripCard(
        label: 'Face scans',
        paths: [for (final face in faces) face.file.path],
        viewerTitle: 'Face scan',
      ),
    );
  }
}
