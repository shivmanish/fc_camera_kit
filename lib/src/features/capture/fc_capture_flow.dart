import 'package:flutter/material.dart';

import '../../core/config/fc_camera_kit.dart';
import '../../core/error/fc_camera_failure.dart';
import '../../core/navigation/fc_navigator.dart';
import '../../core/permissions/fc_permissions.dart';
import '../../core/utils/fc_result.dart';
import '../permissions/presentation/fc_permission_gate.dart';
import '../stamping/fc_stamp_style.dart';
import 'fc_capture_requirements.dart';
import 'fc_capture_result.dart';
import 'fc_capture_source.dart';
import 'fc_image_source.dart';
import 'widgets/fc_processing_screen.dart';
import 'widgets/fc_source_sheet.dart';

/// The whole pipeline behind one call.
///
/// Declared here rather than on the class itself so `core/` keeps its
/// dependency direction: features may reach into core, never the reverse.
extension FcCameraKitCapture on FcCameraKit {
  /// Chooses a source, clears permissions, captures, stamps, compresses and
  /// embeds metadata — then hands back the finished file.
  ///
  /// Omit [source] to let the kit ask. Every abandon path returns
  /// [CancelledFailure], so a user backing out never looks like a crash.
  ///
  /// Per-call arguments override the values given to [FcCameraKit.init].
  Future<FcResult<FcCaptureResult>> capture(
    BuildContext context, {
    FcCaptureSource? source,
    StampPlacement? placement,
    String? dateFormat,
    int? maxBytes,
    FcStampStyle style = const FcStampStyle(),
    bool allowCancel = true,
    FcImageSource? imageSource,
  }) async {
    // Contract: this returns a result, it never throws. Platform channels can
    // fail in ways no individual step anticipates, and a host app should not
    // have to wrap a call that already hands back an FcResult.
    try {
      return await _run(
        context,
        source: source,
        placement: placement,
        dateFormat: dateFormat,
        maxBytes: maxBytes,
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

    // Skips the gate entirely when nothing is needed — gallery with location
    // switched off never sees a prompt.
    if (required.isNotEmpty) {
      final granted = await FcPermissionGate.ensure(
        context,
        required: required,
        allowCancel: allowCancel,
      );
      if (!granted) {
        // Report accurately so a caller showing its own message knows whether
        // to point the user at App Settings.
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

    // Pushed before the picker opens: this route must already be underneath
    // when the camera activity closes, or the host app's screen flashes
    // between the two.
    final outcome = await FcNavigator.push<Object>(
      context,
      (_) => FcProcessingScreen(
        source: resolved,
        imageSource: imageSource,
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
