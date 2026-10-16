import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'fc_camera_permission.dart';
import 'fc_location_permission.dart';
import 'fc_permission_status.dart';
import 'fc_permission_type.dart';

/// Single entry point for kit permissions, delegating to per-type gateways.
class FcPermissions {
  FcPermissions._();

  static FcPermissions? _instance;

  static FcPermissions get instance {
    _instance ??= FcPermissions._();
    return _instance!;
  }

  static const Set<FcPermissionType> captureDefaults = {
    FcPermissionType.camera,
    FcPermissionType.location,
  };

  Future<FcPermissionStatus> statusOf(FcPermissionType type) => switch (type) {
    FcPermissionType.camera => FcCameraPermission.instance.status(),
    FcPermissionType.location => FcLocationPermission.instance.status(),
  };

  Future<Map<FcPermissionType, FcPermissionStatus>> statusOfAll(
    Set<FcPermissionType> types,
  ) async {
    final ordered = types.toList();
    final statuses = await Future.wait(ordered.map(statusOf));
    return Map.fromIterables(ordered, statuses);
  }

  Future<List<FcPermissionType>> missing(Set<FcPermissionType> types) async {
    final statuses = await statusOfAll(types);
    return FcPermissionType.values
        .where((type) => statuses[type]?.isUsable == false)
        .toList();
  }

  Future<bool> allGranted(Set<FcPermissionType> types) async =>
      (await missing(types)).isEmpty;

  /// One grouped native request, so prompts cannot desync or repeat.
  /// The OS still shows one dialog per permission group.
  Future<Map<FcPermissionType, FcPermissionStatus>> requestAll(
    Set<FcPermissionType> types,
  ) async {
    final ordered = FcPermissionType.values.where(types.contains).toList();
    if (ordered.isEmpty) return const {};

    await ordered.map(nativePermission).toList().request();

    // Re-read via gateways: they add accuracy and post-request denial state.
    final statuses = await Future.wait(ordered.map(statusOf));
    return Map.fromIterables(ordered, statuses);
  }

  /// When-in-use only: plain `location` may ask for Always on iOS.
  @visibleForTesting
  static ph.Permission nativePermission(FcPermissionType type) =>
      switch (type) {
        FcPermissionType.camera => ph.Permission.camera,
        FcPermissionType.location => ph.Permission.locationWhenInUse,
      };

  Future<bool> isLocationServiceEnabled() =>
      FcLocationPermission.instance.isServiceEnabled();

  Future<bool> openAppSettings() =>
      FcCameraPermission.instance.openAppSettings();

  Future<bool> openLocationSettings() =>
      FcLocationPermission.instance.openLocationSettings();

  @visibleForTesting
  static void reset() => _instance = null;
}
