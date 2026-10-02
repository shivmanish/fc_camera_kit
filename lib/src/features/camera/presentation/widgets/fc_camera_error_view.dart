import 'package:flutter/material.dart';

import '../../../../core/error/fc_camera_failure.dart';
import '../../../../core/permissions/fc_permissions.dart';
import '../../../../core/ui/fc_ui.dart';

/// The camera couldn't start: why, and the one action that can fix it.
class FcCameraErrorView extends StatelessWidget {
  const FcCameraErrorView({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  final FcCameraFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final failure = this.failure;
    final settings = failure is PermissionFailure && failure.permanentlyDenied;
    final (title, body) = failure is PermissionFailure
        ? ('Camera access needed', 'Allow camera access to take your photo.')
        : (
            'Camera unavailable',
            'Another app may be using the camera. Close it and try again.',
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FcUi.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_rounded,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: const Color(0xB3FFFFFF),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: settings
                  ? FcPermissions.instance.openAppSettings
                  : onRetry,
              style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
              child: Text(settings ? 'Open settings' : 'Try again'),
            ),
            if (settings)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Try again'),
              ),
          ],
        ),
      ),
    );
  }
}
