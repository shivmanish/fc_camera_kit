import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FcApp app(FcEnvironment environment) => FcApp(
    name: 'SarvaSarathi COS',
    version: '2.17.6',
    environment: environment,
  );

  group('software', () {
    test('is name and version in production', () {
      expect(app(FcEnvironment.production).software, 'SarvaSarathi COS 2.17.6');
    });

    test('calls out the build outside production', () {
      expect(app(FcEnvironment.uat).software, 'SarvaSarathi COS 2.17.6 (UAT)');
      expect(
        app(FcEnvironment.development).software,
        'SarvaSarathi COS 2.17.6 (DEV)',
      );
    });
  });

  group('stampLine', () {
    test('is the name alone in production', () {
      expect(app(FcEnvironment.production).stampLine, 'SarvaSarathi COS');
    });

    test('shows version and build outside production', () {
      expect(app(FcEnvironment.uat).stampLine, 'SarvaSarathi COS 2.17.6 (UAT)');
    });
  });
}
