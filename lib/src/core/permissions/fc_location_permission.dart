import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meta/meta.dart';

import '../error/fc_camera_failure.dart';
import '../image/metadata/fc_geo_location.dart';
import '../utils/fc_result.dart';
import 'fc_permission_status.dart';

/// Location permission and position access.
///
/// Built on `geolocator` rather than `permission_handler` because only
/// geolocator also reports whether location *services* are switched on — a
/// device with GPS off is not a denied permission, and the fixes differ.
final class FcLocationPermission {
  FcLocationPermission._();

  static FcLocationPermission? _instance;

  static FcLocationPermission get instance {
    _instance ??= FcLocationPermission._();
    return _instance!;
  }

  /// Device-wide location toggle. Independent of app permission.
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// Permission status, without ever showing a dialog.
  ///
  /// Reports only the permission. A granted permission with location services
  /// switched off is still granted — check [isServiceEnabled] separately.
  Future<FcPermissionStatus> status() async {
    final permission = await Geolocator.checkPermission();
    return mapPermission(permission, accuracy: await _accuracyOrNull());
  }

  /// Whether a position can be read right now. Never prompts.
  Future<bool> hasPermission() async => (await status()).isUsable;

  /// Grants-or-asks. Returns the status on success, an [FcCameraFailure]
  /// describing the blocker otherwise.
  ///
  /// Does not re-prompt when permission is already held, and never prompts at
  /// all when the OS location toggle is off — that dialog cannot fix it.
  Future<FcResult<FcPermissionStatus>> askLocationPermission() async {
    if (!await isServiceEnabled()) {
      return fcFailure(
        const LocationFailure(
          'Location services are turned off on this device.',
        ),
      );
    }

    var permission = await Geolocator.checkPermission();

    // Ask only when asking can achieve something. whileInUse/always are
    // already held, and deniedForever will not surface a dialog at all.
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

  /// Reads the current position, asking for permission first when needed.
  ///
  /// Falls back to the last known fix if a fresh one times out, which is
  /// usually better than failing a capture outright. Reverse geocoding is
  /// opt-in and never fails the call — a missing address is not a missing
  /// location.
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

  /// iOS 14+: asks the user to upgrade an approximate grant to precise.
  ///
  /// [purposeKey] must match an entry in the Info.plist
  /// `NSLocationTemporaryUsageDescriptionDictionary`. A no-op elsewhere.
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

  /// Opens the app's settings page, for recovering a permanent denial.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Opens the device location settings, for recovering a disabled service.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Maps geolocator's permission onto [FcPermissionStatus]. Pure, so the
  /// branching is testable without a platform channel.
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

  /// Joins the meaningful parts of a placemark, skipping blanks and repeats.
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

  /// Last known fix as a consolation prize, or [onMissing] if there is none.
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
    address: resolveAddress
        ? await _reverseGeocode(position.latitude, position.longitude)
        : null,
  );

  /// Best-effort. Geocoding needs a network round trip and is allowed to fail.
  Future<String?> _reverseGeocode(double latitude, double longitude) async {
    try {
      final places = await Geocoding().placemarkFromCoordinates(
        latitude,
        longitude,
      );
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
