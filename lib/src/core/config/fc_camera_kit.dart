import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:meta/meta.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../error/fc_camera_exception.dart';
import '../image/metadata/fc_geo_location.dart';
import '../image/metadata/fc_photo_metadata.dart';
import 'fc_scan_options.dart';

/// Who is taking the photo. A record, so value equality comes for free.
typedef FcUser = ({String id, String name});

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
  String? _deviceModel;
  String? _appName;
  bool _includeDeviceInStamp = false;
  bool _initialized = false;
  int _maxBytes = 5 * 1024 * 1024;
  StampPlacement _placement = StampPlacement.overlay;
  String _dateFormat = 'dd MMM yyyy, hh:mm a';
  bool _requireLocation = false;
  FcScanOptions _scanOptions = const FcScanOptions();

  bool get isInitialized => _initialized;

  /// Current user, or `null` if none is set.
  FcUser? get user => _user;

  /// Which device took the photo, as `name | model`.
  ///
  /// Detected by the kit — there is no setter, because a caller-supplied value
  /// would defeat the point of identifying the handset. Always written to
  /// EXIF, whether or not the visible stamp shows it.
  String? get deviceModel => _deviceModel;

  /// The host app's package name (Android) or bundle id (iOS), detected at
  /// [init] and written to EXIF as "used by".
  String? get appName => _appName;

  /// Whether the device also appears in the visible stamp.
  ///
  /// Off by default: it is useful for auditing but rarely something the person
  /// looking at the photo needs to read.
  bool get includeDeviceInStamp => _includeDeviceInStamp;

  /// Hard ceiling for the returned file, in bytes.
  int get maxBytes => _checked(_maxBytes);

  StampPlacement get placement => _checked(_placement);

  /// `intl` pattern for the date on the stamp.
  String get dateFormat => _checked(_dateFormat);

  /// When true, a capture fails rather than returning a photo with no location.
  bool get requireLocation => _checked(_requireLocation);

  /// Defaults for `scan()`; per-call arguments override them.
  FcScanOptions get scanOptions => _checked(_scanOptions);

  /// Sets up the kit. Safe to call again to change settings.
  ///
  /// Async so later phases can warm up device info without a breaking change.
  Future<void> init({
    FcUser? user,
    int maxBytes = 5 * 1024 * 1024,
    StampPlacement placement = StampPlacement.overlay,
    String dateFormat = 'dd MMM yyyy, hh:mm a',
    bool requireLocation = false,
    bool includeDeviceInStamp = false,
    FcScanOptions scan = const FcScanOptions(),
  }) async {
    if (maxBytes <= 0) {
      throw const ConfigurationException('maxBytes must be positive');
    }
    if (scan.maxPages <= 0) {
      throw const ConfigurationException('scan.maxPages must be positive');
    }
    _user = user;
    _includeDeviceInStamp = includeDeviceInStamp;
    // Detected once here rather than per capture: they are platform calls and
    // neither the handset nor the app changes mid-session.
    final (deviceModel, appName) = await (
      _resolveDeviceModel(),
      _resolveAppName(),
    ).wait;
    _deviceModel = deviceModel;
    _appName = appName;
    _maxBytes = maxBytes;
    _placement = placement;
    _dateFormat = dateFormat;
    _requireLocation = requireLocation;
    _scanOptions = scan;
    _initialized = true;
  }

  /// Sets the user stamped onto subsequent captures.
  void setUser(FcUser user) => _user = user;

  /// Shows or hides the device line in the visible stamp. EXIF is unaffected —
  /// the device is always embedded there.
  void setIncludeDeviceInStamp(bool include) => _includeDeviceInStamp = include;

  /// Changes where the stamp is drawn, for captures from here on.
  ///
  /// Separate from [init] so a host app can expose it as a user setting
  /// without re-running configuration it has already done.
  void setPlacement(StampPlacement placement) => _placement = placement;

  void clearUser() => _user = null;

  /// Snapshots the current user plus the supplied context into the metadata
  /// that gets stamped and written to EXIF.
  FcPhotoMetadata buildMetadata({
    DateTime? capturedAt,
    FcGeoLocation? location,
    String? deviceModel,
    String? note,
  }) => FcPhotoMetadata(
    capturedAt: capturedAt ?? DateTime.now(),
    userId: _user?.id,
    userName: _user?.name,
    location: location,
    deviceModel: deviceModel ?? _deviceModel,
    appId: _appName,
    note: note,
  );

  /// Reads the handset name. Returns `null` rather than throwing — a missing
  /// device name must never stop a capture, and the plugin is unavailable in
  /// unit tests.
  Future<String?> _resolveDeviceModel() async {
    try {
      final info = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return '${android.manufacturer} | ${android.model}';
      }
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        // machine is the hardware identifier (iPhone15,2); name is what the
        // device calls itself. Together they pin down a handset.
        return '${ios.name} | ${ios.utsname.machine}';
      }
    } catch (_) {
      // Unsupported platform or no plugin registered.
    }

    return null;
  }

  /// `null` rather than throwing, like [_resolveDeviceModel]: a missing app id
  /// must never stop a capture.
  Future<String?> _resolveAppName() async {
    // Mobile only, like the device lookup: elsewhere (including widget tests)
    // the plugin has no native side and its reply never arrives.
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    try {
      final appName = (await PackageInfo.fromPlatform()).appName;
      return appName.isEmpty ? null : appName;
    } catch (_) {
      return null;
    }
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
