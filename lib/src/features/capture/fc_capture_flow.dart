import 'package:flutter/material.dart';

import '../../core/config/fc_camera_kit.dart';
import '../../core/error/fc_camera_failure.dart';
import '../../core/image/stamp/fc_stamp_style.dart';
import '../../core/navigation/fc_navigator.dart';
import '../../core/permissions/fc_permissions.dart';
import '../../core/utils/fc_result.dart';
import '../../core/utils/fc_size.dart';
import '../camera/data/datasources/fc_live_camera.dart';
import '../permissions/presentation/fc_permission_gate.dart';
import 'fc_capture_requirements.dart';
import 'fc_capture_result.dart';
import 'fc_capture_source.dart';
import 'fc_image_source.dart';
import 'widgets/fc_processing_screen.dart';
import 'widgets/fc_source_sheet.dart';

/// Capture: pick a source, take or choose a photo, then stamp and compress it.
extension FcCameraKitCapture on FcCameraKit {
  @visibleForTesting
  static FcLiveCamera? debugLiveCamera;

  /// Never throws; every abandon path returns [CancelledFailure].
  Future<FcResult<FcCaptureResult>> capture(
    BuildContext context, {
    FcCaptureSource? source,
    StampPlacement? placement,
    String? dateFormat,
    double? maxMb,
    FcStampStyle style = const FcStampStyle(),
    bool allowCancel = true,
    FcImageSource? imageSource,
  }) async {
    // Never throws: platform channels can fail in ways no step anticipates.
    try {
      return await _run(
        context,
        source: source,
        placement: placement,
        dateFormat: dateFormat,
        maxBytes: maxMb == null ? null : fcBytesFromMb(maxMb),
        style: style,
        allowCancel: allowCancel,
        imageSource: imageSource,
      );
    } catch (error) {
      return fcFailure(UnknownFailure('Capture failed unexpectedly: $error'));
    }
  }

  Future<FcResult<FcCaptureResult>> _run(
    BuildContext context, {
    required FcCaptureSource? source,
    required StampPlacement? placement,
    required String? dateFormat,
    required int? maxBytes,
    required FcStampStyle style,
    required bool allowCancel,
    required FcImageSource? imageSource,
  }) async {
    if (!isInitialized) {
      return fcFailure(
        const ConfigurationFailure(
          'FcCameraKit.instance.init() must be called before capture().',
        ),
      );
    }

    final resolved = source ?? await showSourceSheet(context);
    if (resolved == null) return fcFailure(const CancelledFailure());
    if (!context.mounted) return fcFailure(const CancelledFailure());

    final required = requirementsFor(
      resolved,
      requireLocation: requireLocation,
    );

    // No gate when nothing is needed, e.g. gallery with location off.
    if (required.isNotEmpty) {
      final granted = await FcPermissionGate.ensure(
        context,
        required: required,
        allowCancel: allowCancel,
      );
      if (!granted) {
        // Exact statuses let the caller decide whether to point at App Settings.
        final blocked = await FcPermissions.instance.missing(required);
        final statuses = await FcPermissions.instance.statusOfAll(required);

        return fcFailure(
          PermissionFailure(
            'Required access was not granted.',
            permission: blocked.map((type) => type.name).join(', '),
            permanentlyDenied: blocked.any(
              (type) => statuses[type]?.needsAppSettings ?? false,
            ),
          ),
        );
      }
    }

    if (!context.mounted) return fcFailure(const CancelledFailure());

    // Pushed before the camera opens so the host screen never flashes in between.
    final outcome = await FcNavigator.push<Object>(
      context,
      (_) => FcProcessingScreen(
        source: resolved,
        imageSource: imageSource,
        liveCamera: debugLiveCamera,
        placement: placement,
        dateFormat: dateFormat,
        maxBytes: maxBytes,
        style: style,
      ),
    );

    return switch (outcome) {
      FcCaptureResult() => fcSuccess(outcome),
      FcCameraFailure() => fcFailure(outcome),
      _ => fcFailure(const CancelledFailure()),
    };
  }
}
