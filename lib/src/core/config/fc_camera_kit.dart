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

enum StampPlacement {
  /// Footer drawn over the photo; keeps aspect ratio.
  overlay,

  /// Canvas extended below the photo; hides nothing.
  extend,
}

/// Package entry point: call [init] once, then capture, scan or scanFace.
final class FcCameraKit {
  FcCameraKit._();

  static FcCameraKit? _instance;

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

  String? get deviceMake => _deviceMake;

  /// Read-only on purpose: a caller-set value could not identify the handset.
  String? get deviceModel => _deviceModel;

  FcApp? get app => _app;

  bool get includeDeviceInStamp => _includeDeviceInStamp;

  int get maxBytes => _checked(_maxBytes);

  StampPlacement get placement => _checked(_placement);

  String get dateFormat => _checked(_dateFormat);

  bool get requireLocation => _checked(_requireLocation);

  FcScanOptions get scanOptions => _checked(_scanOptions);

  FcFaceScanOptions get faceScanOptions => _checked(_faceScanOptions);

  /// Safe to call again to change settings; [maxMb] accepts fractions.
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
    // Resolved once: a platform call, and the handset cannot change.
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

  /// Stamp only; EXIF always carries the device.
  void setIncludeDeviceInStamp(bool include) => _includeDeviceInStamp = include;

  void setPlacement(StampPlacement placement) => _placement = placement;

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

  // Field-by-field users hold '' placeholders; treat them as absent.
  static String? _nonBlank(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  // Never throws: a missing device name must not block a capture.
  Future<(String?, String?)> _resolveDevice() async {
    try {
      final info = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return (android.manufacturer, android.model);
      }
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        // Hardware id such as `iPhone15,2`, the nearest iOS has to a model.
        return ('Apple', ios.utsname.machine);
      }
    } catch (_) {
      // Unsupported platform or plugin missing, e.g. in unit tests.
    }

    return (null, null);
  }

  /// Tests only; references held across this call go stale.
  @visibleForTesting
  static void reset() => _instance = null;

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
