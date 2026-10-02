import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final capturedAt = DateTime(2026, 9, 17, 14, 5, 9);

  group('attributesFor', () {
    test('every value is a type both platforms accept', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          userName: 'Asha',
          userId: 'EMP-1',
          deviceModel: 'Pixel 8',
          location: const FcGeoLocation(latitude: 18.52, longitude: 73.85),
        ),
      );

      // native_exif casts blindly to String on Android, except GPS lat/long
      // which it parses as a double. Anything else is a runtime crash.
      for (final entry in attributes.entries) {
        final expectDouble =
            entry.key == 'GPSLatitude' || entry.key == 'GPSLongitude';
        expect(
          entry.value,
          expectDouble ? isA<double>() : isA<String>(),
          reason: '${entry.key} has the wrong type for native_exif',
        );
      }
    });

    test('writes the host app id to UserComment as "used by"', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          appId: 'co.sarvagram.fc_camera_kit.fc_camera_kit_example',
        ),
      );

      expect(
        attributes['UserComment'],
        'co.sarvagram.fc_camera_kit.fc_camera_kit_example',
      );
      expect(attributes['Software'], 'fc_camera_kit');
    });

    test('leaves UserComment out when the app id is unknown', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt),
      );

      expect(attributes.containsKey('UserComment'), isFalse);
    });

    test('omits Orientation — the platforms disagree on its type', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt),
      );

      expect(attributes.containsKey('Orientation'), isFalse);
    });

    test('writes coordinates as decimal degrees, not a DMS string', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          location: const FcGeoLocation(latitude: 18.52043, longitude: 73.8567),
        ),
      );

      expect(attributes['GPSLatitude'], 18.52043);
      expect(attributes['GPSLongitude'], 73.8567);
    });

    test('writes EXIF date format, not the display format', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt),
      );

      expect(attributes['DateTime'], '2026:09:17 14:05:09');
      expect(attributes.containsKey('DateTimeOriginal'), isFalse);
      expect(attributes.containsKey('DateTimeDigitized'), isFalse);
    });

    test('omits GPS tags entirely when there is no fix', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt),
      );

      expect(attributes.keys.where((k) => k.startsWith('GPS')), isEmpty);
    });

    test('keeps the sign and leaves the refs to the platform', () {
      final south = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          location: const FcGeoLocation(latitude: -33.86, longitude: -70.66),
        ),
      );

      // The sign carries the hemisphere; Android's setLatLong writes the ref
      // tags from it, so duplicating them here was redundant.
      expect(south['GPSLatitude'], -33.86);
      expect(south['GPSLongitude'], -70.66);
      expect(south.containsKey('GPSLatitudeRef'), isFalse);
      expect(south.containsKey('GPSLongitudeRef'), isFalse);
    });

    test('puts name and id together in Artist', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          userName: 'Asha Verma',
          userId: 'EMP-2291',
        ),
      );

      expect(attributes['Artist'], 'Asha Verma | EMP-2291');
      expect(attributes.containsKey('UserComment'), isFalse);
    });

    test('omits Artist entirely when there is no user', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt),
      );

      expect(attributes.containsKey('Artist'), isFalse);
    });

    test('writes the readable place alongside the coordinates', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          location: const FcGeoLocation(
            latitude: 18.52,
            longitude: 73.85,
            address: 'Shivajinagar, Pune',
          ),
        ),
      );

      expect(attributes['ImageDescription'], 'Shivajinagar, Pune');
      expect(attributes['GPSLatitude'], 18.52);
    });

    test('omits the place when geocoding gave nothing', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          location: const FcGeoLocation(latitude: 1, longitude: 2),
        ),
      );

      expect(attributes.containsKey('ImageDescription'), isFalse);
    });

    test('embeds the device so a photo traces back to a handset', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt, deviceModel: 'Google Pixel 8'),
      );

      expect(attributes['Model'], 'Google Pixel 8');
    });
  });

  group('FcCompressionPolicy', () {
    const policy = FcCompressionPolicy();

    test('nextDimension shrinks until the floor, then gives up', () {
      expect(policy.nextDimension(4000), (4000 * 0.85).round());
      expect(policy.nextDimension(1100), isNull, reason: 'below minDimension');
    });

    test('quality steps descend from the ceiling to the floor', () {
      expect(policy.qualitySteps.first, policy.startQuality);
      expect(policy.qualitySteps.last, policy.minQuality);
      expect(policy.qualitySteps, hasLength(policy.qualityRungs));
    });

    test('steps are strictly descending, so the first fit is the best fit', () {
      final steps = policy.qualitySteps;

      for (var i = 1; i < steps.length; i++) {
        expect(steps[i], lessThan(steps[i - 1]));
      }
    });

    test('bounds the attempts — this is the cost that matters', () {
      // Every attempt ships the whole frame across the platform channel, so
      // the ladder must stay short. A binary search over 70..95 took six.
      expect(policy.qualitySteps.length, lessThanOrEqualTo(5));
    });

    test('rejects a ladder with no room to descend', () {
      expect(
        () => FcCompressionPolicy(qualityRungs: 1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a quality range that cannot work', () {
      expect(
        () => FcCompressionPolicy(minQuality: 99, startQuality: 80),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
