import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must run before runApp; reading a setting earlier throws.
  await FcCameraKit.instance.init(
    // Hardcoded for the demo; a real app reads these from its build.
    app: const FcApp(
      name: 'FC Camera Kit Example',
      version: '1.0.0',
      environment: FcEnvironment.development,
    ),
    user: const FcUser(
      id: 'EMP-2291',
      name: 'Asha Verma',
      role: 'Field Officer',
      branch: 'Baramati',
    ),
    maxMb: 5,
    placement: StampPlacement.extend,
    dateFormat: 'dd MMM yyyy, hh:mm a',
    requireLocation: true,
    // Defaults; each scan() call may override them.
    scan: const FcScanOptions(
      maxPages: 2,
      source: FcScanSource.cameraAndGallery,
    ),
  );

  runApp(const FcCameraKitExampleApp());
}
