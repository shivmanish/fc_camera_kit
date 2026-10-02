import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Once, before runApp. Reading any setting before this throws.
  await FcCameraKit.instance.init(
    user: (id: 'EMP-2291', name: 'Asha Verma'),
    maxBytes: 5 * 1024 * 1024,
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
