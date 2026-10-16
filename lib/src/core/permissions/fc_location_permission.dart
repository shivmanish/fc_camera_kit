import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meta/meta.dart';

import '../error/fc_camera_failure.dart';
import '../image/metadata/fc_geo_location.dart';
import '../utils/fc_result.dart';
import 'fc_permission_status.dart';

/// Uses geolocator because it also reports whether location services are on.
final class FcLocationPermission {
  FcLocationPermission._();

  static FcLocationPermission? _instance;

  static FcLocationPermission get instance {
    _instance ??= FcLocationPermission._();
    return _instance!;
  }

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// Ignores the service toggle; check [isServiceEnabled] separately.
  Future<FcPermissionStatus> status() async {
    final permission = await Geolocator.checkPermission();
    return mapPermission(permission, accuracy: await _accuracyOrNull());
  }

  Future<bool> hasPermission() async => (await status()).isUsable;

  /// Skips the prompt when services are off, since granting cannot fix that.
  Future<FcResult<FcPermissionStatus>> askLocationPermission() async {
    if (!await isServiceEnabled()) {
      return fcFailure(
        const LocationFailure(
          'Location services are turned off on this device.',
        ),
      );
    }

    var permission = await Geolocator.checkPermission();

    // deniedForever shows no dialog, so only these states are worth asking.
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await Geolocator.requestPermission();
    }

    final status = mapPermission(permission, accuracy: await _accuracyOrNull());
    if (status.isUsable) return fcSuccess(status);

    return fcFailure(
      PermissionFailure(
        status.needsAppSettings
            ? 'Location permission is permanently denied. Enable it in Settings.'
            : 'Location permission was denied.',
        permission: 'location',
        permanentlyDenied: status.needsAppSettings,
      ),
    );
  }

  /// Falls back to the last known fix; geocoding never fails the call.
  Future<FcResult<FcGeoLocation>> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.best,
    Duration timeout = const Duration(seconds: 15),
    bool requestIfNeeded = true,
    bool allowLastKnown = true,
    bool resolveAddress = false,
  }) async {
    final permission = requestIfNeeded
        ? await askLocationPermission()
        : await _requireExistingPermission();

    final blocker = permission.failureOrNull;
    if (blocker != null) return fcFailure(blocker);

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );
      return fcSuccess(await _toGeoLocation(position, resolveAddress));
    } on TimeoutException {
      return _lastKnownOr(
        allowLastKnown,
        resolveAddress,
        LocationFailure('No location fix within ${timeout.inSeconds}s.'),
      );
    } catch (error) {
      return _lastKnownOr(
        allowLastKnown,
        resolveAddress,
        LocationFailure('Could not read the device location: $error'),
      );
    }
  }

  /// iOS 14+; [purposeKey] must be in Info.plist's temporary usage keys.
  Future<bool> requestPreciseAccuracy({
    String purposeKey = 'FcCameraKitPreciseLocation',
  }) async {
    try {
      final result = await Geolocator.requestTemporaryFullAccuracy(
        purposeKey: purposeKey,
      );
      return result == LocationAccuracyStatus.precise;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @visibleForTesting
  static FcPermissionStatus mapPermission(
    LocationPermission permission, {
    LocationAccuracyStatus? accuracy,
  }) => switch (permission) {
    LocationPermission.always || LocationPermission.whileInUse =>
      accuracy == LocationAccuracyStatus.reduced
          ? FcPermissionStatus.grantedReduced
          : FcPermissionStatus.granted,
    LocationPermission.deniedForever => FcPermissionStatus.deniedForever,
    LocationPermission.denied ||
    LocationPermission.unableToDetermine => FcPermissionStatus.denied,
  };

  /// Skips blank and repeated placemark parts.
  @visibleForTesting
  static String? formatAddress(Placemark place) {
    final parts = <String?>[
      place.subLocality,
      place.locality,
      place.administrativeArea,
      place.postalCode,
      place.country,
    ];

    final seen = <String>{};
    final kept = <String>[];
    for (final part in parts) {
      if (part == null || part.trim().isEmpty) continue;
      if (seen.add(part)) kept.add(part);
    }

    return kept.isEmpty ? null : kept.join(', ');
  }

  @visibleForTesting
  static void reset() => _instance = null;

  Future<FcResult<FcPermissionStatus>> _requireExistingPermission() async {
    final current = await status();
    if (current.isUsable) return fcSuccess(current);

    if (!await isServiceEnabled()) {
      return fcFailure(
        const LocationFailure(
          'Location services are turned off on this device.',
        ),
      );
    }

    return fcFailure(
      PermissionFailure(
        'Location permission is not granted.',
        permission: 'location',
        permanentlyDenied: current.needsAppSettings,
      ),
    );
  }

  Future<FcResult<FcGeoLocation>> _lastKnownOr(
    bool allowLastKnown,
    bool resolveAddress,
    FcCameraFailure onMissing,
  ) async {
    if (!allowLastKnown) return fcFailure(onMissing);

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) return fcFailure(onMissing);
      return fcSuccess(await _toGeoLocation(last, resolveAddress));
    } catch (_) {
      return fcFailure(onMissing);
    }
  }

  Future<FcGeoLocation> _toGeoLocation(
    Position position,
    bool resolveAddress,
  ) async => FcGeoLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracyMeters: position.accuracy,
    altitudeMeters: position.altitude,
    fixedAt: position.timestamp,
    isMocked: position.isMocked,
    address: resolveAddress
        ? await _reverseGeocode(position.latitude, position.longitude)
        : null,
  );

  // Best effort: needs the network and may fail.
  Future<String?> _reverseGeocode(double latitude, double longitude) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      return places.isEmpty ? null : formatAddress(places.first);
    } catch (_) {
      return null;
    }
  }

  Future<LocationAccuracyStatus?> _accuracyOrNull() async {
    try {
      return await Geolocator.getLocationAccuracy();
    } catch (_) {
      return null;
    }
  }
}
