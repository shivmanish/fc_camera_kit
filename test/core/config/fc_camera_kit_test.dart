import 'dart:async';

import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(FcCameraKit.reset);

  group('instance', () {
    test('is the same object across reads', () {
      expect(FcCameraKit.instance, same(FcCameraKit.instance));
    });

    test('reset yields a fresh instance with defaults back', () async {
      await FcCameraKit.instance.init(maxBytes: 1024);
      final before = FcCameraKit.instance;

      FcCameraKit.reset();

      expect(FcCameraKit.instance, isNot(same(before)));
      expect(FcCameraKit.instance.isInitialized, isFalse);
    });
  });

  group('init', () {
    // Platform lookups must never block init() off-device: a host app's own
    // widget tests call it, and an unanswered channel there waits forever.
    testWidgets('completes inside a widget test', (tester) async {
      var done = false;
      unawaited(FcCameraKit.instance.init().then((_) => done = true));
      await tester.pump();

      expect(done, isTrue);
      expect(FcCameraKit.instance.appName, isNull);
    });

    test('reading settings before init throws', () {
      expect(
        () => FcCameraKit.instance.maxBytes,
        throwsA(isA<ConfigurationException>()),
      );
      expect(FcCameraKit.instance.isInitialized, isFalse);
    });

    test('applies defaults', () async {
      await FcCameraKit.instance.init();

      expect(FcCameraKit.instance.isInitialized, isTrue);
      expect(FcCameraKit.instance.maxBytes, 5 * 1024 * 1024);
      expect(FcCameraKit.instance.placement, StampPlacement.overlay);
      expect(FcCameraKit.instance.requireLocation, isFalse);
    });

    test('applies overrides', () async {
      await FcCameraKit.instance.init(
        maxBytes: 1024,
        placement: StampPlacement.extend,
        dateFormat: 'yyyy-MM-dd',
        requireLocation: true,
      );

      expect(FcCameraKit.instance.maxBytes, 1024);
      expect(FcCameraKit.instance.placement, StampPlacement.extend);
      expect(FcCameraKit.instance.dateFormat, 'yyyy-MM-dd');
      expect(FcCameraKit.instance.requireLocation, isTrue);
    });

    test('rejects a non-positive maxBytes', () {
      expect(
        () => FcCameraKit.instance.init(maxBytes: 0),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('is safe to call twice', () async {
      await FcCameraKit.instance.init(maxBytes: 1024);
      await FcCameraKit.instance.init(maxBytes: 2048);

      expect(FcCameraKit.instance.maxBytes, 2048);
    });
  });

  group('user', () {
    const asha = (id: 'EMP-2291', name: 'Asha Verma');

    test('is null until set', () async {
      await FcCameraKit.instance.init();

      expect(FcCameraKit.instance.user, isNull);
    });

    test('setUser and clearUser', () async {
      await FcCameraKit.instance.init();

      FcCameraKit.instance.setUser(asha);
      expect(FcCameraKit.instance.user, asha);

      FcCameraKit.instance.clearUser();
      expect(FcCameraKit.instance.user, isNull);
    });

    test('init can seed the user', () async {
      await FcCameraKit.instance.init(user: asha);

      expect(FcCameraKit.instance.user, asha);
    });

    test('records compare by value', () {
      const same = (id: 'EMP-2291', name: 'Asha Verma');

      expect(asha, same);
    });
  });

  group('setPlacement', () {
    test(
      'changes placement without disturbing the rest of the config',
      () async {
        await FcCameraKit.instance.init(
          user: (id: 'EMP-1', name: 'Asha'),
          maxBytes: 4096,
        );

        FcCameraKit.instance.setPlacement(StampPlacement.extend);

        expect(FcCameraKit.instance.placement, StampPlacement.extend);
        expect(FcCameraKit.instance.maxBytes, 4096);
        expect(FcCameraKit.instance.user?.name, 'Asha');
      },
    );

    test('is reversible', () async {
      await FcCameraKit.instance.init();

      FcCameraKit.instance.setPlacement(StampPlacement.extend);
      FcCameraKit.instance.setPlacement(StampPlacement.overlay);

      expect(FcCameraKit.instance.placement, StampPlacement.overlay);
    });
  });

  group('device', () {
    test('is off in the stamp by default', () async {
      await FcCameraKit.instance.init();

      expect(FcCameraKit.instance.includeDeviceInStamp, isFalse);
    });

    test('init can turn the stamp line on', () async {
      await FcCameraKit.instance.init(includeDeviceInStamp: true);

      expect(FcCameraKit.instance.includeDeviceInStamp, isTrue);
    });

    test('the setter toggles it after init', () async {
      await FcCameraKit.instance.init();

      FcCameraKit.instance.setIncludeDeviceInStamp(true);
      expect(FcCameraKit.instance.includeDeviceInStamp, isTrue);

      FcCameraKit.instance.setIncludeDeviceInStamp(false);
      expect(FcCameraKit.instance.includeDeviceInStamp, isFalse);
    });

    test('detection failing never blocks init', () async {
      // No plugin in a unit test, so the lookup throws and is swallowed.
      await FcCameraKit.instance.init();

      expect(FcCameraKit.instance.isInitialized, isTrue);
      expect(FcCameraKit.instance.deviceModel, isNull);
    });

    test('whatever was detected reaches the metadata', () async {
      await FcCameraKit.instance.init();

      expect(
        FcCameraKit.instance.buildMetadata().deviceModel,
        FcCameraKit.instance.deviceModel,
      );
    });
  });

  group('buildMetadata', () {
    const pune = FcGeoLocation(latitude: 18.52043, longitude: 73.856743);

    test('carries the current user', () async {
      await FcCameraKit.instance.init(user: (id: 'EMP-1', name: 'Asha'));

      final meta = FcCameraKit.instance.buildMetadata();

      expect(meta.userId, 'EMP-1');
      expect(meta.userName, 'Asha');
      expect(meta.hasUser, isTrue);
    });

    test('leaves user fields null when none is set', () async {
      await FcCameraKit.instance.init();

      expect(FcCameraKit.instance.buildMetadata().hasUser, isFalse);
    });

    test('takes the supplied location and defaults the timestamp', () async {
      await FcCameraKit.instance.init();

      final meta = FcCameraKit.instance.buildMetadata(location: pune);

      expect(meta.location, pune);
      expect(meta.capturedAt, isNotNull);
    });

    test('reflects a user set after init', () async {
      await FcCameraKit.instance.init();
      FcCameraKit.instance.setUser((id: 'EMP-9', name: 'Ravi'));

      expect(FcCameraKit.instance.buildMetadata().userId, 'EMP-9');
    });
  });
}
