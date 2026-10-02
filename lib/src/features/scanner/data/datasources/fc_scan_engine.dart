import '../../../../core/config/fc_scan_options.dart';

/// A document scanner that returns page file paths.
///
/// Throws `FcCameraException`s; returns `null` when the user cancels.
abstract interface class FcScanEngine {
  Future<List<String>?> scan(FcScanOptions options);

  Future<void> clearCache();
}
