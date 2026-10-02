import 'package:flutter/material.dart';

import '../../../../core/error/fc_camera_failure.dart';
import '../../../../core/permissions/fc_permissions.dart';
import '../../../../core/ui/fc_ui.dart';

class FcScanErrorView extends StatelessWidget {
  const FcScanErrorView({
    required this.failure,
    required this.onRetry,
    required this.onClose,
    super.key,
  });

  final FcCameraFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  bool get _needsSettings =>
      failure is PermissionFailure &&
      (failure as PermissionFailure).permanentlyDenied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, body) = _copyFor(failure);

    return Padding(
      padding: const EdgeInsets.all(FcUi.gutter),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FcCloseButton(onPressed: onClose),
          ),
          const Spacer(),
          FcIconBadge(
            icon: Icons.document_scanner_rounded,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          FcPrimaryButton(
            label: _needsSettings ? 'Open settings' : 'Try again',
            onPressed: _needsSettings
                ? FcPermissions.instance.openAppSettings
                : onRetry,
          ),
          // Back from Settings with access granted, the user continues here.
          if (_needsSettings) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: FcUi.buttonHeight,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static (String, String) _copyFor(FcCameraFailure failure) =>
      switch (failure) {
        PermissionFailure(:final permission) => (
          'Access needed',
          'Allow $permission access to scan documents.',
        ),
        SizeLimitFailure() => (
          'Scan too large',
          'The page could not be made small enough. Try scanning it again.',
        ),
        StorageFailure() => (
          'Could not save the scan',
          'Free up some storage and try again.',
        ),
        _ => (
          'Scan failed',
          'Something went wrong while scanning. Please try again.',
        ),
      };
}
