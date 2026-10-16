import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../error/fc_camera_exception.dart';
import '../image/metadata/fc_geo_location.dart';
import '../image/metadata/fc_photo_metadata.dart';
import '../utils/fc_size.dart';
import 'fc_app.dart';
import 'fc_face_scan_options.dart';
import 'fc_scan_options.dart';

part 'fc_user.dart';

/// Where the who/when/where stamp is drawn.
enum StampPlacement {
  /// Translucent footer on top of the photo. Aspect ratio kept, pixels covered.
  overlay,

  /// Canvas grown below the photo. Nothing hidden, aspect ratio changes.
  extend,
}

/// Entry point and single source of package-wide settings.
///
/// Call [init] once in `main()`, then [setUser] whenever the signed-in user
/// changes. Features never read this directly — [buildMetadata] snapshots it
/// and the result is passed down explicitly, which keeps them testable.
final class FcCameraKit {
  FcCameraKit._();

  static FcCameraKit? _instance;

  /// The one instance for the app lifecycle, created on first access.
  static FcCameraKit get instance {
    _instance ??= FcCameraKit._();
    return _instance!;
  }

  FcUser? _user;
  String? _deviceMake;
  String? _deviceModel;
  FcApp? _app;
  bool _includeDeviceInStamp = false;
  bool _initialized = false;
  int _maxBytes = 5 * 1024 * 1024;
  StampPlacement _placement = StampPlacement.overlay;
  String _dateFormat = 'dd MMM yyyy, hh:mm a';
  bool _requireLocation = false;
  FcScanOptions _scanOptions = const FcScanOptions();
  FcFaceScanOptions _faceScanOptions = const FcFaceScanOptions();

  bool get isInitialized => _initialized;

  /// Who made the device that took the photo, e.g. `Lenovo`.
  ///
  /// Detected by the kit, like [deviceModel].
  String? get deviceMake => _deviceMake;

  /// Which device took the photo, e.g. `TB328XU`.
  ///
  /// Detected by the kit — there is no setter, because a caller-supplied value
  /// would defeat the point of identifying the handset. Always written to
  /// EXIF, whether or not the visible stamp shows it.
  String? get deviceModel => _deviceModel;

  /// The host app given to [init], for EXIF `Software` and the stamp.
  FcApp? get app => _app;

  /// Whether the device also appears in the visible stamp.
  ///
  /// Off by default: it is useful for auditing but rarely something the person
  /// looking at the photo needs to read.
  bool get includeDeviceInStamp => _includeDeviceInStamp;

  /// Hard ceiling for the returned file, in bytes (from [init]'s `maxMb`).
  int get maxBytes => _checked(_maxBytes);

  StampPlacement get placement => _checked(_placement);

  /// `intl` pattern for the date on the stamp.
  String get dateFormat => _checked(_dateFormat);

  /// When true, a capture fails rather than returning a photo with no location.
  bool get requireLocation => _checked(_requireLocation);

  /// Defaults for `scan()`; per-call arguments override them.
  FcScanOptions get scanOptions => _checked(_scanOptions);

  /// Defaults for `scanFace()`; per-call arguments override them.
  FcFaceScanOptions get faceScanOptions => _checked(_faceScanOptions);

  /// Sets up the kit. Safe to call again to change settings.
  ///
  /// Async so later phases can warm up device info without a breaking change.
  ///
  /// [maxMb] is the size ceiling in megabytes; fractions work, e.g. `0.5`.
  ///
  /// [app] is the host app, its version and build environment, for EXIF
  /// `Software` and the stamp; name and version must not be blank.
  Future<void> init({
    FcUser? user,
    double maxMb = 5,
    StampPlacement placement = StampPlacement.overlay,
    String dateFormat = 'dd MMM yyyy, hh:mm a',
    bool requireLocation = false,
    bool includeDeviceInStamp = false,
    FcScanOptions scan = const FcScanOptions(),
    FcFaceScanOptions faceScan = const FcFaceScanOptions(),
    required FcApp app,
  }) async {
    final maxBytes = fcBytesFromMb(maxMb);
    if (maxBytes <= 0) {
      throw const ConfigurationException('maxMb must be positive');
    }
    if (app.name.trim().isEmpty) {
      throw const ConfigurationException('app.name must not be blank');
    }
    if (app.version.trim().isEmpty) {
      throw const ConfigurationException('app.version must not be blank');
    }
    if (scan.maxPages <= 0) {
      throw const ConfigurationException('scan.maxPages must be positive');
    }
    if (faceScan.blinks <= 0) {
      throw const ConfigurationException('faceScan.blinks must be positive');
    }
    _user = user;
    _includeDeviceInStamp = includeDeviceInStamp;
    _app = FcApp(
      name: app.name.trim(),
      version: app.version.trim(),
      environment: app.environment,
    );
    // Detected once here rather than per capture: a platform call, and the
    // handset doesn't change mid-session.
    final (make, model) = await _resolveDevice();
    _deviceMake = make;
    _deviceModel = model;
    _maxBytes = maxBytes;
    _placement = placement;
    _dateFormat = dateFormat;
    _requireLocation = requireLocation;
    _scanOptions = scan;
    _faceScanOptions = faceScan;
    _initialized = true;
  }

  /// Shows or hides the device line in the visible stamp. EXIF is unaffected —
  /// the device is always embedded there.
  void setIncludeDeviceInStamp(bool include) => _includeDeviceInStamp = include;

  /// Changes where the stamp is drawn, for captures from here on.
  ///
  /// Separate from [init] so a host app can expose it as a user setting
  /// without re-running configuration it has already done.
  void setPlacement(StampPlacement placement) => _placement = placement;

  /// Snapshots the current user plus the supplied context into the metadata
  /// that gets stamped and written to EXIF.
  FcPhotoMetadata buildMetadata({
    DateTime? capturedAt,
    FcGeoLocation? location,
    String? deviceMake,
    String? deviceModel,
    String? note,
  }) => FcPhotoMetadata(
    capturedAt: capturedAt ?? DateTime.now(),
    userId: _nonBlank(_user?.id),
    userName: _nonBlank(_user?.name),
    userRole: _nonBlank(_user?.role),
    userBranch: _nonBlank(_user?.branch),
    location: location,
    deviceMake: deviceMake ?? _deviceMake,
    deviceModel: deviceModel ?? _deviceModel,
    app: _app,
    note: note,
  );

  // A user built one field at a time holds '' placeholders; drop them so EXIF
  // and the stamp see missing, not empty.
  static String? _nonBlank(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  /// Reads the handset's maker and model. Returns nulls rather than throwing —
  /// a missing device name must never stop a capture, and the plugin is
  /// unavailable in unit tests.
  Future<(String?, String?)> _resolveDevice() async {
    try {
      final info = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return (android.manufacturer, android.model);
      }
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        // machine is the hardware identifier (iPhone15,2), the closest iOS
        // gets to a model number.
        return ('Apple', ios.utsname.machine);
      }
    } catch (_) {
      // Unsupported platform or no plugin registered.
    }

    return (null, null);
  }

  /// Throws the instance away so the next [instance] read builds a fresh one.
  ///
  /// Tests only. Any reference held across this call goes stale, so always go
  /// through [FcCameraKit.instance] rather than caching it.
  @visibleForTesting
  static void reset() => _instance = null;

  /// Guards every settings read, so a missing [init] fails loudly and early.
  T _checked<T>(T value) {
    if (!_initialized) {
      throw const ConfigurationException(
        'FcCameraKit.instance.init() must be called before use, '
        'usually in main() before runApp().',
      );
    }
    return value;
  }
}
