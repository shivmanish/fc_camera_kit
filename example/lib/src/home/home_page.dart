import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'home_cubit.dart';
import 'home_state.dart';
import 'widgets/access_card.dart';
import 'widgets/action_bar.dart';
import 'widgets/capture_card.dart';
import 'widgets/face_card.dart';
import 'widgets/identity_card.dart';
import 'widgets/location_card.dart';
import 'widgets/metadata_card.dart';
import 'widgets/scan_card.dart';
import 'widgets/stamp_card.dart';
import 'widgets/stamp_viewer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit()..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  /// No `source`, so the kit shows its chooser and asks only what it needs.
  Future<void> _capture(BuildContext context) async {
    final cubit = context.read<HomeCubit>();
    cubit.captureStarted();

    final result = await FcCameraKit.instance.capture(context);

    cubit.captureFinished(result);

    // Open the viewer at once; a thumbnail is too small to read the stamp.
    final capture = result.valueOrNull;
    if (capture != null && context.mounted) {
      await openStampViewer(context, capture.file.path);
    }

    await cubit.refreshAccess();
  }

  Future<void> _scan(BuildContext context) async {
    final cubit = context.read<HomeCubit>();
    cubit.captureStarted();

    final result = await FcCameraKit.instance.scan(
      context,
      stamp: cubit.state.stampScans,
    );

    cubit.scanFinished(result);
  }

  Future<void> _scanFace(BuildContext context) async {
    final cubit = context.read<HomeCubit>();
    cubit.captureStarted();

    final result = await FcCameraKit.instance.scanFace(
      context,
      stamp: cubit.state.stampScans,
    );

    cubit.faceScanFinished(result);
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FC Camera Kit'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      // Disabled mid-flow so a double tap cannot start a second one.
      bottomNavigationBar: BlocBuilder<HomeCubit, HomeState>(
        buildWhen: (previous, current) =>
            previous.capturing != current.capturing,
        builder: (context, state) => ActionBar(
          enabled: !state.capturing,
          onCapture: () => _capture(context),
          onScan: () => _scan(context),
          onFace: () => _scanFace(context),
        ),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<HomeCubit, HomeState>(
            listenWhen: (previous, current) =>
                previous.locationError != current.locationError &&
                current.locationError != null,
            listener: (context, state) {
              _showError(context, state.locationError!.message);
              context.read<HomeCubit>().dismissLocationError();
            },
          ),
          BlocListener<HomeCubit, HomeState>(
            listenWhen: (previous, current) =>
                previous.captureError != current.captureError &&
                current.captureError != null,
            listener: (context, state) {
              _showError(context, state.captureError!.message);
              context.read<HomeCubit>().dismissCaptureError();
            },
          ),
        ],
        child: const SingleChildScrollView(
          // Leaves room for the extended FAB.
          padding: EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            children: [
              IdentityCard(),
              SizedBox(height: 24),
              CaptureCard(),
              ScanCard(),
              FaceCard(),
              StampCard(),
              SizedBox(height: 24),
              AccessCard(),
              SizedBox(height: 24),
              LocationCard(),
              SizedBox(height: 24),
              MetadataCard(),
            ],
          ),
        ),
      ),
    );
  }
}
