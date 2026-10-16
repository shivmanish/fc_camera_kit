import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final capturedAt = DateTime(2026, 9, 17, 14, 5, 9);
  const app = FcApp(
    name: 'SarvaSarathi COS',
    version: '2.17.6',
    environment: FcEnvironment.production,
  );

  group('attributesFor', () {
    const location = FcGeoLocation(latitude: 18.52, longitude: 73.85);

    test('on Android every value is a String, GPS lat/long a double', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          userName: 'Asha',
          userId: 'EMP-1',
          deviceMake: 'Google',
          deviceModel: 'Pixel 8',
          app: app,
          imageId: FcExifWriter.newImageId(),
          location: FcGeoLocation(
            latitude: 18.52,
            longitude: 73.85,
            accuracyMeters: 12.5,
            address: 'Shivajinagar, Pune',
            fixedAt: DateTime.utc(2026, 9, 17, 8, 35, 1),
            isMocked: true,
          ),
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

    test('on iOS numeric tags are numbers, as ImageIO wants', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          location: const FcGeoLocation(
            latitude: 18.52,
            longitude: 73.85,
            accuracyMeters: 12.5,
          ),
        ),
        android: false,
      );

      expect(attributes['Orientation'], 1);
      expect(attributes['GPSHPositioningError'], 12.5);
      // Only Android's string-to-bytes path can express the version bytes.
      expect(attributes.containsKey('GPSVersionID'), isFalse);
    });

    test('names the app and its version in Software', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt, app: app),
      );

      expect(attributes['Software'], 'SarvaSarathi COS 2.17.6');
    });

    test('calls out a build outside production in Software', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          app: const FcApp(
            name: 'SarvaSarathi COS',
            version: '2.17.6',
            environment: FcEnvironment.uat,
          ),
        ),
      );

      expect(attributes['Software'], 'SarvaSarathi COS 2.17.6 (UAT)');
    });

    test('writes the photo id to ImageUniqueID', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          imageId: '3f9c2a7e5b1d4e8fa0c64b2d9e7f1a35',
        ),
      );

      expect(attributes['ImageUniqueID'], '3f9c2a7e5b1d4e8fa0c64b2d9e7f1a35');
    });

    test('leaves ImageUniqueID out until the id is assigned', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt),
      );

      expect(attributes.containsKey('ImageUniqueID'), isFalse);
    });

    test('marks a mocked fix, in the method and beside the place', () {
      final meta = FcPhotoMetadata(
        capturedAt: capturedAt,
        location: const FcGeoLocation(
          latitude: 18.52,
          longitude: 73.85,
          address: 'Baner, Pune',
          isMocked: true,
        ),
      );
      final android = FcExifWriter.attributesFor(meta);

      expect(android['GPSProcessingMethod'], 'ASCII\x00\x00\x00MOCKED');
      expect(android['ImageDescription'], 'Baner, Pune (MOCKED)');
      expect(
        FcExifWriter.attributesFor(meta, android: false)['GPSProcessingMethod'],
        'MOCKED',
      );
    });

    test('says nothing about the method for a real fix', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt, location: location),
      );

      expect(attributes.containsKey('GPSProcessingMethod'), isFalse);
    });

    test('leaves Software out when the app is unknown', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt),
      );

      expect(attributes.containsKey('Software'), isFalse);
    });

    test('names the kit in UserComment, behind the charset header', () {
      final meta = FcPhotoMetadata(capturedAt: capturedAt);

      // Android's ExifInterface writes no header of its own; iOS does.
      expect(
        FcExifWriter.attributesFor(meta)['UserComment'],
        'ASCII\x00\x00\x00fc_camera_kit',
      );
      expect(
        FcExifWriter.attributesFor(meta, android: false)['UserComment'],
        'fc_camera_kit',
      );
    });

    test('marks the pixels upright, as Orientation 1', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt),
      );

      // Left out, ExifInterface writes 0, which is not a valid orientation.
      expect(attributes['Orientation'], '1');
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

    test('writes the capture time as all three EXIF dates', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: DateTime(2026, 9, 17, 14, 5, 9, 42)),
      );

      expect(attributes['DateTime'], '2026:09:17 14:05:09');
      expect(attributes['DateTimeOriginal'], '2026:09:17 14:05:09');
      expect(attributes['DateTimeDigitized'], '2026:09:17 14:05:09');
      expect(attributes['SubSecTimeOriginal'], '042');
      expect(attributes['SubSecTime'], '042');
      expect(attributes['SubSecTimeDigitized'], '042');
    });

    test('writes the UTC offset beside the local time', () {
      final utc = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: DateTime.utc(2026, 9, 17, 8, 35, 9)),
      );
      final local = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt),
      );

      expect(utc['DateTimeOriginal'], '2026:09:17 08:35:09');
      expect(utc['OffsetTimeOriginal'], '+00:00');
      for (final tag in [
        'OffsetTime',
        'OffsetTimeOriginal',
        'OffsetTimeDigitized',
      ]) {
        expect(local[tag], matches(RegExp(r'^[+-]\d{2}:\d{2}$')), reason: tag);
      }
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

      // The sign carries the hemisphere; both platforms write the ref tags
      // from it, so duplicating them here was redundant.
      expect(south['GPSLatitude'], -33.86);
      expect(south['GPSLongitude'], -70.66);
      expect(south.containsKey('GPSLatitudeRef'), isFalse);
      expect(south.containsKey('GPSLongitudeRef'), isFalse);
    });

    test('writes the GPS version, datum and accuracy', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          location: const FcGeoLocation(
            latitude: 18.52,
            longitude: 73.85,
            accuracyMeters: 12.34,
          ),
        ),
      );

      expect(attributes['GPSVersionID'], '\x02\x03\x00\x00');
      expect(attributes['GPSMapDatum'], 'WGS-84');
      expect(attributes['GPSHPositioningError'], '1234/100');
    });

    test('writes when the fix was taken, in UTC', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          location: FcGeoLocation(
            latitude: 18.52,
            longitude: 73.85,
            fixedAt: DateTime.utc(2026, 9, 17, 23, 59, 58).toLocal(),
          ),
        ),
      );

      expect(attributes['GPSDateStamp'], '2026:09:17');
      expect(attributes['GPSTimeStamp'], '23:59:58');
    });

    test('leaves out accuracy and fix time when the platform gave none', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(capturedAt: capturedAt, location: location),
      );

      expect(attributes.containsKey('GPSHPositioningError'), isFalse);
      expect(attributes.containsKey('GPSDateStamp'), isFalse);
      expect(attributes.containsKey('GPSTimeStamp'), isFalse);
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
    });

    test('appends the role to Artist when set', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          userName: 'Asha Verma',
          userId: 'EMP-2291',
          userRole: 'Field Officer',
        ),
      );

      expect(attributes['Artist'], 'Asha Verma | EMP-2291 | Field Officer');
    });

    test('appends the branch to Artist after the role', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          userName: 'Asha Verma',
          userId: 'EMP-2291',
          userRole: 'Field Officer',
          userBranch: 'Baramati',
        ),
      );

      expect(
        attributes['Artist'],
        'Asha Verma | EMP-2291 | Field Officer | Baramati',
      );
    });

    test('a branch without a role leaves no stray separator', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          userName: 'Asha Verma',
          userId: 'EMP-2291',
          userBranch: 'Baramati',
        ),
      );

      expect(attributes['Artist'], 'Asha Verma | EMP-2291 | Baramati');
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
        FcPhotoMetadata(capturedAt: capturedAt, location: location),
      );

      expect(attributes.containsKey('ImageDescription'), isFalse);
    });

    test('leaves out text that is not ASCII rather than writing ?', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          userName: 'आशा',
          app: const FcApp(
            name: 'सारथी',
            version: '1.0.0',
            environment: FcEnvironment.production,
          ),
          location: const FcGeoLocation(
            latitude: 18.52,
            longitude: 73.85,
            address: 'शिवाजीनगर, पुणे',
          ),
        ),
      );

      expect(attributes.containsKey('Artist'), isFalse);
      expect(attributes.containsKey('ImageDescription'), isFalse);
      expect(attributes.containsKey('Software'), isFalse);
    });

    test('embeds the device as Make and Model', () {
      final attributes = FcExifWriter.attributesFor(
        FcPhotoMetadata(
          capturedAt: capturedAt,
          deviceMake: 'Google',
          deviceModel: 'Pixel 8',
        ),
      );

      expect(attributes['Make'], 'Google');
      expect(attributes['Model'], 'Pixel 8');
    });
  });

  group('newImageId', () {
    test('is a UUID v4 in the 32 hex digits ImageUniqueID takes', () {
      final id = FcExifWriter.newImageId();

      expect(
        id,
        matches(RegExp(r'^[0-9a-f]{12}4[0-9a-f]{3}[89ab][0-9a-f]{15}$')),
      );
    });

    test('is new every time', () {
      final ids = {for (var i = 0; i < 1000; i++) FcExifWriter.newImageId()};

      expect(ids, hasLength(1000));
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
