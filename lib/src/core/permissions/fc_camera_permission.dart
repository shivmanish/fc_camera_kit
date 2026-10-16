import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../error/fc_camera_failure.dart';
import '../utils/fc_result.dart';
import 'fc_permission_status.dart';

final class FcCameraPermission {
  FcCameraPermission._();

  static FcCameraPermission? _instance;

  static FcCameraPermission get instance {
    _instance ??= FcCameraPermission._();
    return _instance!;
  }

  /// Android only reports a permanent denial after [askCameraPermission].
  Future<FcPermissionStatus> status() async =>
      mapStatus(await ph.Permission.camera.status);

  Future<bool> hasPermission() async => (await status()).isUsable;

  Future<FcResult<FcPermissionStatus>> askCameraPermission() async {
    var current = await status();

    if (!current.isUsable) {
      current = mapStatus(await ph.Permission.camera.request());
    }

    if (current.isUsable) return fcSuccess(current);

    return fcFailure(
      PermissionFailure(
        current.needsAppSettings
            ? 'Camera permission is permanently denied. Enable it in Settings.'
            : 'Camera permission was denied.',
        permission: 'camera',
        permanentlyDenied: current.needsAppSettings,
      ),
    );
  }

  Future<bool> openAppSettings() => ph.openAppSettings();

  @visibleForTesting
  static FcPermissionStatus mapStatus(ph.PermissionStatus status) =>
      switch (status) {
        ph.PermissionStatus.granted ||
        ph.PermissionStatus.provisional => FcPermissionStatus.granted,
        ph.PermissionStatus.limited => FcPermissionStatus.grantedReduced,
        ph.PermissionStatus.permanentlyDenied ||
        ph.PermissionStatus.restricted => FcPermissionStatus.deniedForever,
        ph.PermissionStatus.denied => FcPermissionStatus.denied,
      };

  @visibleForTesting
  static void reset() => _instance = null;
}
