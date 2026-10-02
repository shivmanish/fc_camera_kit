import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'fc_camera_permission.dart';
import 'fc_location_permission.dart';
import 'fc_permission_status.dart';
import 'fc_permission_type.dart';

/// One entry point for every permission the kit needs.
///
/// Delegates to the per-permission gateways so each keeps its own platform
/// quirks, and adds the group operations the capture gate needs.
class FcPermissions {
  FcPermissions._();

  static FcPermissions? _instance;

  static FcPermissions get instance {
    _instance ??= FcPermissions._();
    return _instance!;
  }

  /// Everything a capture needs by default.
  static const Set<FcPermissionType> captureDefaults = {
    FcPermissionType.camera,
    FcPermissionType.location,
  };

  Future<FcPermissionStatus> statusOf(FcPermissionType type) => switch (type) {
    FcPermissionType.camera => FcCameraPermission.instance.status(),
    FcPermissionType.location => FcLocationPermission.instance.status(),
  };

  /// Status of each, checked concurrently. Never prompts.
  Future<Map<FcPermissionType, FcPermissionStatus>> statusOfAll(
    Set<FcPermissionType> types,
  ) async {
    final ordered = types.toList();
    final statuses = await Future.wait(ordered.map(statusOf));
    return Map.fromIterables(ordered, statuses);
  }

  /// The subset that is not usable yet, in a stable order.
  Future<List<FcPermissionType>> missing(Set<FcPermissionType> types) async {
    final statuses = await statusOfAll(types);
    return FcPermissionType.values
        .where((type) => statuses[type]?.isUsable == false)
        .toList();
  }

  Future<bool> allGranted(Set<FcPermissionType> types) async =>
      (await missing(types)).isEmpty;

  /// Asks for everything in [types] as **one grouped request**.
  ///
  /// A single `ActivityCompat.requestPermissions` call on Android, with one
  /// request code and one callback — our code never regains control between
  /// prompts, so the sequence cannot desync or double-prompt.
  ///
  /// Android still renders one system dialog per permission *group*, so camera
  /// and location appear back to back. That is the OS, not us; no API merges
  /// them into a single dialog. iOS likewise shows one alert per type.
  Future<Map<FcPermissionType, FcPermissionStatus>> requestAll(
    Set<FcPermissionType> types,
  ) async {
    final ordered = FcPermissionType.values.where(types.contains).toList();
    if (ordered.isEmpty) return const {};

    await ordered.map(nativePermission).toList().request();

    // Re-read through the gateways rather than trusting the returned map: the
    // location status also folds in geolocator's precise/reduced accuracy, and
    // Android only reports a permanent denial once a request has happened.
    final statuses = await Future.wait(ordered.map(statusOf));
    return Map.fromIterables(ordered, statuses);
  }

  /// Maps our type onto the plugin's.
  ///
  /// Location is `locationWhenInUse`, never `location`: the latter can escalate
  /// to Always on iOS, and our Info.plist carries only a When-In-Use usage
  /// description — requesting Always without one is an App Store rejection.
  @visibleForTesting
  static ph.Permission nativePermission(FcPermissionType type) =>
      switch (type) {
        FcPermissionType.camera => ph.Permission.camera,
        FcPermissionType.location => ph.Permission.locationWhenInUse,
      };

  /// Device-wide location toggle. Only meaningful once location is granted.
  Future<bool> isLocationServiceEnabled() =>
      FcLocationPermission.instance.isServiceEnabled();

  Future<bool> openAppSettings() =>
      FcCameraPermission.instance.openAppSettings();

  Future<bool> openLocationSettings() =>
      FcLocationPermission.instance.openLocationSettings();

  @visibleForTesting
  static void reset() => _instance = null;
}
