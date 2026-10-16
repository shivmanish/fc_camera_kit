import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('nativePermission', () {
    test('camera maps to the camera permission', () {
      expect(
        FcPermissions.nativePermission(FcPermissionType.camera),
        Permission.camera,
      );
    });

    test('location maps to when-in-use, never to always', () {
      final mapped = FcPermissions.nativePermission(FcPermissionType.location);

      expect(mapped, Permission.locationWhenInUse);

      // iOS: requesting Always without its Info.plist key means rejection.
      expect(mapped, isNot(Permission.location));
      expect(mapped, isNot(Permission.locationAlways));
    });

    test('every type has a mapping', () {
      for (final type in FcPermissionType.values) {
        expect(
          () => FcPermissions.nativePermission(type),
          returnsNormally,
          reason: '$type must map to a native permission',
        );
      }
    });
  });

  group('captureDefaults', () {
    test('is camera plus location', () {
      expect(FcPermissions.captureDefaults, {
        FcPermissionType.camera,
        FcPermissionType.location,
      });
    });
  });
}
