import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/fc_camera_kit.dart';
import '../../core/config/fc_scan_options.dart';
import '../../core/error/fc_camera_failure.dart';
import '../../core/navigation/fc_navigator.dart';
import '../../core/utils/fc_result.dart';
import '../stamping/fc_stamp_style.dart';
import 'domain/entities/fc_scan_result.dart';
import 'domain/repositories/fc_scan_repository.dart';
import 'presentation/pages/fc_scanner_page.dart';

extension FcCameraKitScan on FcCameraKit {
  static Future<FcResult<FcScanResult>>? _inFlight;

  /// Replaces the platform scanner in tests.
  @visibleForTesting
  static FcScanRepository? debugRepository;

  /// Scans a document and returns the finished pages. Never throws.
  ///
  /// Arguments left `null` come from `init(...)`; the stamp ones match
  /// `capture()`. A call made while a
  /// scan is running gets that scan's result instead of opening a second one.
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
  }) {
    final running = _inFlight;
    if (running != null) return running;

    final next = _scan(
      context,
      maxPages: maxPages,
      source: source,
      enhancement: enhancement,
      embedMetadata: embedMetadata,
      maxBytes: maxBytes,
      stamp: stamp,
      placement: placement,
      dateFormat: dateFormat,
      style: style,
    );
    _inFlight = next;
    unawaited(
      next.whenComplete(() {
        if (identical(_inFlight, next)) _inFlight = null;
      }),
    );
    return next;
  }

  Future<FcResult<FcScanResult>> _scan(
    BuildContext context, {
    required int? maxPages,
    required FcScanSource? source,
    required FcScanEnhancement? enhancement,
    required bool? embedMetadata,
    required int? maxBytes,
    required bool? stamp,
    required StampPlacement? placement,
    required String? dateFormat,
    required FcStampStyle style,
  }) async {
    if (!isInitialized) {
      return fcFailure(
        const ConfigurationFailure(
          'FcCameraKit.instance.init() must be called before scan().',
        ),
      );
    }

    FcScanResult? result;
    FcCameraFailure? failure;
    try {
      // The page closes its own route; the callbacks only record the outcome.
      await FcNavigator.push<Object?>(
        context,
        (_) => FcScannerPage(
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
          onCompleted: (scan) => result = scan,
          onCancelled: () => failure = const CancelledFailure(),
          onFailed: (error) => failure = error,
        ),
        // The platform scanner opens over this route at once.
        animate: false,
      );
    } catch (error) {
      return fcFailure(UnknownFailure('Scan failed unexpectedly: $error'));
    }

    final scan = result;
    if (scan != null) return fcSuccess(scan);
    return fcFailure(failure ?? const CancelledFailure());
  }
}
