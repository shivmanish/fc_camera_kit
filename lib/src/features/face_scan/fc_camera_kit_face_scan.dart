import 'package:flutter/widgets.dart';

import '../../core/config/fc_camera_kit.dart';
import '../../core/image/stamp/fc_stamp_style.dart';
import '../../core/navigation/fc_flow.dart';
import '../../core/utils/fc_result.dart';
import '../camera/data/datasources/fc_live_camera.dart';
import 'domain/entities/fc_face_result.dart';
import 'domain/repositories/fc_face_detector.dart';
import 'domain/repositories/fc_face_repository.dart';
import 'presentation/pages/fc_face_scan_page.dart';

extension FcCameraKitFaceScan on FcCameraKit {
  /// Replace the device camera, ML Kit and the file pipeline in tests.
  @visibleForTesting
  static FcLiveCamera? debugCamera;
  @visibleForTesting
  static FcFaceDetector? debugDetector;
  @visibleForTesting
  static FcFaceRepository? debugRepository;

  /// Frames the user's face, checks for a blink and returns the selfie.
  /// Never throws.
  ///
  /// Arguments left `null` come from `init(...)`; the stamp ones match
  /// `capture()` and `scan()`. A call made while one runs gets that run's
  /// result instead of opening a second one.
  Future<FcResult<FcFaceResult>> scanFace(
    BuildContext context, {
    int? blinks,
    int? maxBytes,
    bool? embedMetadata,
    bool? stamp,
    StampPlacement? placement,
    String? dateFormat,
    FcStampStyle style = const FcStampStyle(),
    Duration? autoCaptureAfter,
    bool? mirrorSelfie,
  }) => FcFlow.run<FcFaceResult>(
    context,
    key: #fcFaceScan,
    page: (callbacks) => FcFaceScanPage(
      blinks: blinks,
      maxBytes: maxBytes,
      embedMetadata: embedMetadata,
      stamp: stamp,
      placement: placement,
      dateFormat: dateFormat,
      style: style,
      autoCaptureAfter: autoCaptureAfter,
      mirrorSelfie: mirrorSelfie,
      camera: debugCamera,
      detector: debugDetector,
      repository: debugRepository,
      onCompleted: callbacks.onCompleted,
      onCancelled: callbacks.onCancelled,
      onFailed: callbacks.onFailed,
    ),
  );
}
