import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../error/fc_camera_failure.dart';
import '../utils/fc_result.dart';
import 'fc_permission_status.dart';

/// Camera permission, via `permission_handler`.
///
/// Unlike location there is no device-wide service toggle, so the state space
/// stops at granted / denied / permanently denied.
final class FcCameraPermission {
  FcCameraPermission._();

  static FcCameraPermission? _instance;

  static FcCameraPermission get instance {
    _instance ??= FcCameraPermission._();
    return _instance!;
  }

  /// Current status, without prompting.
  ///
  /// Android never reports [FcPermissionStatus.deniedForever] here — the OS has
  /// no API for it. Only [askCameraPermission] can tell the two apart.
  Future<FcPermissionStatus> status() async =>
      mapStatus(await ph.Permission.camera.status);

  Future<bool> hasPermission() async => (await status()).isUsable;

  /// Grants-or-asks. Does not re-prompt when permission is already held.
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
