import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Once, before runApp. Reading any setting before this throws.
  await FcCameraKit.instance.init(
    // EXIF Software and a stamp line. A real app reads the version with
    // package_info_plus and the environment from its build flavour.
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
    // Scanner defaults; scan() can override any of them per call.
    scan: const FcScanOptions(
      maxPages: 2,
      source: FcScanSource.cameraAndGallery,
    ),
  );

  runApp(const FcCameraKitExampleApp());
}
