import '../../../../core/config/fc_scan_options.dart';

/// Throws `FcCameraException`; returns `null` on user cancel.
abstract interface class FcScanEngine {
  Future<List<String>?> scan(FcScanOptions options);

  Future<void> clearCache();
}
