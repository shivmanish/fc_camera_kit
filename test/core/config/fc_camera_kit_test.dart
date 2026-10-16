import 'dart:async';

import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fc_test_app.dart';

void main() {
  setUp(FcCameraKit.reset);

  group('instance', () {
    test('is the same object across reads', () {
      expect(FcCameraKit.instance, same(FcCameraKit.instance));
    });

    test('reset yields a fresh instance with defaults back', () async {
      await FcCameraKit.instance.init(app: fcTestApp, maxMb: 1);
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
      unawaited(
        FcCameraKit.instance.init(app: fcTestApp).then((_) => done = true),
      );
      await tester.pump();

      expect(done, isTrue);
      expect(FcCameraKit.instance.app, fcTestApp);
    });

    test('init keeps the app it is given, trimmed', () async {
      await FcCameraKit.instance.init(
        app: const FcApp(
          name: '  SarvaSarathi COS  ',
          version: ' 2.17.6 ',
          environment: FcEnvironment.uat,
        ),
      );
      const trimmed = FcApp(
        name: 'SarvaSarathi COS',
        version: '2.17.6',
        environment: FcEnvironment.uat,
      );

      expect(FcCameraKit.instance.app, trimmed);
      expect(FcCameraKit.instance.buildMetadata().app, trimmed);
    });

    test('init rejects a blank app name or version', () {
      expect(
        () => FcCameraKit.instance.init(
          app: const FcApp(
            name: ' ',
            version: '1.0.0',
            environment: FcEnvironment.production,
          ),
        ),
        throwsA(isA<ConfigurationException>()),
      );
      expect(
        () => FcCameraKit.instance.init(
          app: const FcApp(
            name: 'Test App',
            version: ' ',
            environment: FcEnvironment.production,
          ),
        ),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('reading settings before init throws', () {
      expect(
        () => FcCameraKit.instance.maxBytes,
        throwsA(isA<ConfigurationException>()),
      );
      expect(FcCameraKit.instance.isInitialized, isFalse);
    });

    test('applies defaults', () async {
      await FcCameraKit.instance.init(app: fcTestApp);

      expect(FcCameraKit.instance.isInitialized, isTrue);
      expect(FcCameraKit.instance.maxBytes, 5 * 1024 * 1024);
      expect(FcCameraKit.instance.placement, StampPlacement.overlay);
      expect(FcCameraKit.instance.requireLocation, isFalse);
    });

    test('applies overrides', () async {
      await FcCameraKit.instance.init(
        app: fcTestApp,
        maxMb: 0.5,
        placement: StampPlacement.extend,
        dateFormat: 'yyyy-MM-dd',
        requireLocation: true,
      );

      expect(FcCameraKit.instance.maxBytes, 512 * 1024);
      expect(FcCameraKit.instance.placement, StampPlacement.extend);
      expect(FcCameraKit.instance.dateFormat, 'yyyy-MM-dd');
      expect(FcCameraKit.instance.requireLocation, isTrue);
    });

    test('rejects a non-positive maxMb', () {
      expect(
        () => FcCameraKit.instance.init(app: fcTestApp, maxMb: 0),
        throwsA(isA<ConfigurationException>()),
      );
      expect(
        () => FcCameraKit.instance.init(app: fcTestApp, maxMb: -1),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('is safe to call twice', () async {
      await FcCameraKit.instance.init(app: fcTestApp, maxMb: 1);
      await FcCameraKit.instance.init(app: fcTestApp, maxMb: 2);

      expect(FcCameraKit.instance.maxBytes, 2 * 1024 * 1024);
    });
  });

  group('user', () {
    const asha = FcUser(
      id: 'EMP-2291',
      name: 'Asha Verma',
      role: 'Field Officer',
      branch: 'Baramati',
    );

    test('is null until set', () async {
      await FcCameraKit.instance.init(app: fcTestApp);

      expect(FcCameraKit.instance.user, isNull);
    });

    test('setUser and clearUser', () async {
      await FcCameraKit.instance.init(app: fcTestApp);

      FcCameraKit.instance.setUser(asha);
      expect(FcCameraKit.instance.user, asha);

      FcCameraKit.instance.clearUser();
      expect(FcCameraKit.instance.user, isNull);
    });

    test('init can seed the user', () async {
      await FcCameraKit.instance.init(app: fcTestApp, user: asha);

      expect(FcCameraKit.instance.user, asha);
    });

    test('records compare by value', () {
      const same = FcUser(
        id: 'EMP-2291',
        name: 'Asha Verma',
        role: 'Field Officer',
        branch: 'Baramati',
      );

      expect(asha, same);
    });
  });

  group('setPlacement', () {
    test(
      'changes placement without disturbing the rest of the config',
      () async {
        await FcCameraKit.instance.init(
          app: fcTestApp,
          user: const FcUser(id: 'EMP-1', name: 'Asha', branch: ''),
          maxMb: 4,
        );

        FcCameraKit.instance.setPlacement(StampPlacement.extend);

        expect(FcCameraKit.instance.placement, StampPlacement.extend);
        expect(FcCameraKit.instance.maxBytes, 4 * 1024 * 1024);
        expect(FcCameraKit.instance.user?.name, 'Asha');
      },
    );

    test('is reversible', () async {
      await FcCameraKit.instance.init(app: fcTestApp);

      FcCameraKit.instance.setPlacement(StampPlacement.extend);
      FcCameraKit.instance.setPlacement(StampPlacement.overlay);

      expect(FcCameraKit.instance.placement, StampPlacement.overlay);
    });
  });

  group('device', () {
    test('is off in the stamp by default', () async {
      await FcCameraKit.instance.init(app: fcTestApp);

      expect(FcCameraKit.instance.includeDeviceInStamp, isFalse);
    });

    test('init can turn the stamp line on', () async {
      await FcCameraKit.instance.init(
        app: fcTestApp,
        includeDeviceInStamp: true,
      );

      expect(FcCameraKit.instance.includeDeviceInStamp, isTrue);
    });

    test('the setter toggles it after init', () async {
      await FcCameraKit.instance.init(app: fcTestApp);

      FcCameraKit.instance.setIncludeDeviceInStamp(true);
      expect(FcCameraKit.instance.includeDeviceInStamp, isTrue);

      FcCameraKit.instance.setIncludeDeviceInStamp(false);
      expect(FcCameraKit.instance.includeDeviceInStamp, isFalse);
    });

    test('detection failing never blocks init', () async {
      // No plugin in a unit test, so the lookup throws and is swallowed.
      await FcCameraKit.instance.init(app: fcTestApp);

      expect(FcCameraKit.instance.isInitialized, isTrue);
      expect(FcCameraKit.instance.deviceModel, isNull);
    });

    test('whatever was detected reaches the metadata', () async {
      await FcCameraKit.instance.init(app: fcTestApp);

      expect(
        FcCameraKit.instance.buildMetadata().deviceModel,
        FcCameraKit.instance.deviceModel,
      );
    });
  });

  group('buildMetadata', () {
    const pune = FcGeoLocation(latitude: 18.52043, longitude: 73.856743);

    test('carries the current user', () async {
      await FcCameraKit.instance.init(
        app: fcTestApp,
        user: const FcUser(
          id: 'EMP-1',
          name: 'Asha',
          role: 'Field Officer',
          branch: 'Baramati',
        ),
      );

      final meta = FcCameraKit.instance.buildMetadata();

      expect(meta.userId, 'EMP-1');
      expect(meta.userName, 'Asha');
      expect(meta.userRole, 'Field Officer');
      expect(meta.userBranch, 'Baramati');
      expect(meta.hasUser, isTrue);
    });

    test('userBranch sets the branch, and a blank one is left out', () async {
      await FcCameraKit.instance.init(
        app: fcTestApp,
        user: const FcUser(id: 'EMP-1', name: 'Asha', branch: ''),
      );
      expect(FcCameraKit.instance.buildMetadata().userBranch, isNull);

      FcCameraKit.instance.userBranch = 'Baramati';
      expect(FcCameraKit.instance.buildMetadata().userBranch, 'Baramati');

      FcCameraKit.instance.userBranch = '  ';
      expect(FcCameraKit.instance.buildMetadata().userBranch, isNull);
    });

    test('leaves user fields null when none is set', () async {
      await FcCameraKit.instance.init(app: fcTestApp);

      expect(FcCameraKit.instance.buildMetadata().hasUser, isFalse);
    });

    test('takes the supplied location and defaults the timestamp', () async {
      await FcCameraKit.instance.init(app: fcTestApp);

      final meta = FcCameraKit.instance.buildMetadata(location: pune);

      expect(meta.location, pune);
      expect(meta.capturedAt, isNotNull);
    });

    test('reflects a user set after init', () async {
      await FcCameraKit.instance.init(app: fcTestApp);
      FcCameraKit.instance.setUser(
        const FcUser(id: 'EMP-9', name: 'Ravi', branch: ''),
      );

      expect(FcCameraKit.instance.buildMetadata().userId, 'EMP-9');
    });
  });
}
