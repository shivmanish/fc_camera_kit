import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

Placemark placemark({
  String? subLocality,
  String? locality,
  String? administrativeArea,
  String? postalCode,
  String? country,
}) => Placemark(
  subLocality: subLocality,
  locality: locality,
  administrativeArea: administrativeArea,
  postalCode: postalCode,
  country: country,
);

void main() {
  group('FcPermissionStatus', () {
    test('only granted states are usable', () {
      expect(FcPermissionStatus.granted.isUsable, isTrue);
      expect(FcPermissionStatus.grantedReduced.isUsable, isTrue);
      expect(FcPermissionStatus.denied.isUsable, isFalse);
      expect(FcPermissionStatus.deniedForever.isUsable, isFalse);
    });

    test('only a permanent denial routes to App Settings', () {
      expect(FcPermissionStatus.deniedForever.needsAppSettings, isTrue);
      expect(FcPermissionStatus.denied.needsAppSettings, isFalse);
      expect(FcPermissionStatus.granted.needsAppSettings, isFalse);
    });

    test('says nothing about the device location toggle', () {
      // A granted permission is granted whether or not GPS is on. Folding the
      // service into this enum made the gate open a permission sheet that
      // could not fix a disabled service.
      for (final status in FcPermissionStatus.values) {
        expect(status.name, isNot(contains('service')));
      }
    });
  });

  group('mapPermission', () {
    test('whileInUse and always are granted', () {
      expect(
        FcLocationPermission.mapPermission(LocationPermission.whileInUse),
        FcPermissionStatus.granted,
      );
      expect(
        FcLocationPermission.mapPermission(LocationPermission.always),
        FcPermissionStatus.granted,
      );
    });

    test('reduced accuracy downgrades a grant', () {
      expect(
        FcLocationPermission.mapPermission(
          LocationPermission.whileInUse,
          accuracy: LocationAccuracyStatus.reduced,
        ),
        FcPermissionStatus.grantedReduced,
      );
    });

    test('precise accuracy keeps a full grant', () {
      expect(
        FcLocationPermission.mapPermission(
          LocationPermission.always,
          accuracy: LocationAccuracyStatus.precise,
        ),
        FcPermissionStatus.granted,
      );
    });

    test('reduced accuracy does not promote a denial', () {
      expect(
        FcLocationPermission.mapPermission(
          LocationPermission.denied,
          accuracy: LocationAccuracyStatus.reduced,
        ),
        FcPermissionStatus.denied,
      );
    });

    test('deniedForever is kept distinct from denied', () {
      expect(
        FcLocationPermission.mapPermission(LocationPermission.deniedForever),
        FcPermissionStatus.deniedForever,
      );
      expect(
        FcLocationPermission.mapPermission(LocationPermission.denied),
        FcPermissionStatus.denied,
      );
    });

    test('unableToDetermine is treated as retryable', () {
      expect(
        FcLocationPermission.mapPermission(
          LocationPermission.unableToDetermine,
        ),
        FcPermissionStatus.denied,
      );
    });
  });

  group('formatAddress', () {
    test('joins the parts that are present', () {
      expect(
        FcLocationPermission.formatAddress(
          placemark(
            subLocality: 'Shivajinagar',
            locality: 'Pune',
            administrativeArea: 'Maharashtra',
            postalCode: '411005',
            country: 'India',
          ),
        ),
        'Shivajinagar, Pune, Maharashtra, 411005, India',
      );
    });

    test('skips nulls and blanks', () {
      expect(
        FcLocationPermission.formatAddress(
          placemark(locality: 'Pune', administrativeArea: '   ', country: ''),
        ),
        'Pune',
      );
    });

    test('collapses duplicates, which geocoders do emit', () {
      expect(
        FcLocationPermission.formatAddress(
          placemark(subLocality: 'Pune', locality: 'Pune', country: 'India'),
        ),
        'Pune, India',
      );
    });

    test('returns null when nothing is usable', () {
      expect(FcLocationPermission.formatAddress(placemark()), isNull);
    });
  });
}
