import 'package:flutter/material.dart';

import '../../../core/navigation/fc_navigator.dart';
import '../../../core/permissions/fc_permission_type.dart';
import '../../../core/permissions/fc_permissions.dart';
import '../../../core/ui/fc_ui.dart';
import 'widgets/fc_location_service_dialog.dart';
import 'widgets/fc_permission_sheet.dart';

/// The one call to make before opening the camera.
///
/// ```dart
/// if (!await FcPermissionGate.ensure(context)) return;
/// // safe to capture
/// ```
///
/// Runs the full flow: check, explain, request, recover from a permanent
/// denial, then confirm location services are on. Returns `true` only when
/// every requirement is satisfied.
abstract final class FcPermissionGate {
  /// Nothing is shown when everything is already granted, so this is cheap to
  /// call on every capture.
  static Future<bool> ensure(
    BuildContext context, {
    Set<FcPermissionType> required = FcPermissions.captureDefaults,
    bool allowCancel = true,
  }) async {
    if (!await FcPermissions.instance.allGranted(required)) {
      if (!context.mounted) return false;

      final granted = await FcNavigator.showSheet<bool>(
        context,
        (_) => FcPermissionSheet(required: required, allowCancel: allowCancel),
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FcUi.sheetRadius),
          ),
        ),
      );

      if (granted != true) return false;
    }

    if (!required.contains(FcPermissionType.location)) return true;
    if (!context.mounted) return false;

    return _ensureLocationService(context, allowCancel: allowCancel);
  }

  /// Permission granted but the device toggle is off — a different fix, so a
  /// different surface.
  static Future<bool> _ensureLocationService(
    BuildContext context, {
    required bool allowCancel,
  }) async {
    if (await FcPermissions.instance.isLocationServiceEnabled()) return true;
    if (!context.mounted) return false;

    final enabled = await FcNavigator.showDialog<bool>(
      context,
      (_) => FcLocationServiceDialog(allowCancel: allowCancel),
      barrierDismissible: false,
    );

    return enabled ?? false;
  }
}
