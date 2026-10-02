import 'package:flutter/material.dart';

import '../../core/config/fc_camera_kit.dart';
import '../../core/config/fc_scan_options.dart';
import '../../core/image/stamp/fc_stamp_style.dart';
import '../../core/navigation/fc_flow.dart';
import '../../core/utils/fc_result.dart';
import 'domain/entities/fc_scan_result.dart';
import 'domain/repositories/fc_scan_repository.dart';
import 'presentation/pages/fc_scanner_page.dart';

extension FcCameraKitScan on FcCameraKit {
  /// Replaces the platform scanner in tests.
  @visibleForTesting
  static FcScanRepository? debugRepository;

  /// Scans a document and returns the finished pages. Never throws.
  ///
  /// Arguments left `null` come from `init(...)`; the stamp ones match
  /// `capture()`. A call made while a scan is running gets that scan's result
  /// instead of opening a second one.
  Future<FcResult<FcScanResult>> scan(
    BuildContext context, {
    int? maxPages,
    FcScanSource? source,
    FcScanEnhancement? enhancement,
    bool? embedMetadata,
    int? maxBytes,
    bool? stamp,
    StampPlacement? placement,
    String? dateFormat,
    FcStampStyle style = const FcStampStyle(),
  }) => FcFlow.run<FcScanResult>(
    context,
    key: #fcScan,
    page: (callbacks) => FcScannerPage(
      maxPages: maxPages,
      source: source,
      enhancement: enhancement,
      embedMetadata: embedMetadata,
      maxBytes: maxBytes,
      stamp: stamp,
      placement: placement,
      dateFormat: dateFormat,
      style: style,
      repository: debugRepository,
      onCompleted: callbacks.onCompleted,
      onCancelled: callbacks.onCancelled,
      onFailed: callbacks.onFailed,
    ),
  );
}
