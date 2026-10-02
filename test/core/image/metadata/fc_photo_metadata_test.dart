import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final capturedAt = DateTime.utc(2026, 9, 16, 10, 30);

  const pune = FcGeoLocation(
    latitude: 18.520430,
    longitude: 73.856743,
    accuracyMeters: 12.5,
    address: 'Shivajinagar, Pune',
  );

  group('FcGeoLocation', () {
    test('formats coordinates to six decimal places', () {
      expect(pune.coordinates, '18.520430, 73.856743');
    });

    test('compares by value', () {
      expect(
        const FcGeoLocation(latitude: 1, longitude: 2),
        const FcGeoLocation(latitude: 1, longitude: 2),
      );
      expect(
        const FcGeoLocation(latitude: 1, longitude: 2),
        isNot(const FcGeoLocation(latitude: 1, longitude: 3)),
      );
    });

    test('copyWith replaces only what it is given', () {
      final updated = pune.copyWith(address: 'Kothrud, Pune');

      expect(updated.address, 'Kothrud, Pune');
      expect(updated.latitude, pune.latitude);
      expect(updated.accuracyMeters, pune.accuracyMeters);
    });
  });

  group('FcPhotoMetadata', () {
    test('only capturedAt is required', () {
      final meta = FcPhotoMetadata(capturedAt: capturedAt);

      expect(meta.hasLocation, isFalse);
      expect(meta.hasUser, isFalse);
    });

    test('hasUser is true when either name or id is set', () {
      expect(
        FcPhotoMetadata(capturedAt: capturedAt, userId: 'EMP-2291').hasUser,
        isTrue,
      );
      expect(
        FcPhotoMetadata(capturedAt: capturedAt, userName: 'Asha').hasUser,
        isTrue,
      );
    });

    test('hasLocation reflects a resolved fix', () {
      final meta = FcPhotoMetadata(capturedAt: capturedAt, location: pune);

      expect(meta.hasLocation, isTrue);
    });

    test('compares by value, including nested location', () {
      expect(
        FcPhotoMetadata(capturedAt: capturedAt, location: pune),
        FcPhotoMetadata(capturedAt: capturedAt, location: pune),
      );
      expect(
        FcPhotoMetadata(capturedAt: capturedAt, location: pune),
        isNot(
          FcPhotoMetadata(
            capturedAt: capturedAt,
            location: const FcGeoLocation(latitude: 0, longitude: 0),
          ),
        ),
      );
    });

    test('copyWith attaches a late-resolved location', () {
      final resolved = FcPhotoMetadata(
        capturedAt: capturedAt,
        userName: 'Asha',
      ).copyWith(location: pune);

      expect(resolved.location, pune);
      expect(resolved.userName, 'Asha');
      expect(resolved.capturedAt, capturedAt);
    });
  });
}
