import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../home_cubit.dart';
import '../home_state.dart';
import 'image_strip_card.dart';

/// Every page scanned this session, newest first.
class ScanCard extends StatelessWidget {
  const ScanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<HomeCubit, HomeState, List<FcScannedPage>>(
      selector: (state) => state.scans,
      builder: (context, pages) => ImageStripCard(
        label: 'Scanned documents',
        viewerTitle: 'Scanned page',
        paths: [for (final page in pages) page.file.path],
      ),
    );
  }
}
