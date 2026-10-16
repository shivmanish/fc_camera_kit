import 'dart:io' show Platform;
import 'dart:math' show Random;

import 'package:intl/intl.dart' show DateFormat;
import 'package:meta/meta.dart';
import 'package:native_exif/native_exif.dart';

import '../../error/fc_camera_exception.dart';
import 'fc_geo_location.dart';
import 'fc_photo_metadata.dart';

/// Embeds photo metadata as EXIF; must run after the final JPEG encode.
abstract final class FcExifWriter {
  /// Budget kept free for the EXIF block, which is about 1 KB.
  static const reservedBytes = 4 * 1024;

  // Fixed by the EXIF spec.
  static final _exifDate = DateFormat('yyyy:MM:dd HH:mm:ss');
  static final _gpsDate = DateFormat('yyyy:MM:dd');
  static final _gpsTime = DateFormat('HH:mm:ss');

  static const _kit = 'fc_camera_kit';

  static Future<FcPhotoMetadata> write(
    String path,
    FcPhotoMetadata meta,
  ) async {
    // New id per file, even when pages share one metadata.
    final written = meta.copyWith(imageId: newImageId());
    Exif? exif;
    try {
      exif = await Exif.fromPath(path);
      await exif.writeAttributes(
        attributesFor(written, android: Platform.isAndroid),
      );
      return written;
    } catch (error, stackTrace) {
      throw MetadataException(
        'Could not write EXIF metadata.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      await exif?.close();
    }
  }

  /// UUID v4 as 32 hex digits without dashes, as `ImageUniqueID` expects.
  @visibleForTesting
  static String newImageId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = bytes[6] & 0x0F | 0x40; // version 4
    bytes[8] = bytes[8] & 0x3F | 0x80; // RFC 4122 variant
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  // Android takes strings (GPS lat/long as doubles); iOS wants numbers for
  // numeric tags. A wrong type crashes or corrupts silently.
  @visibleForTesting
  static Map<String, Object> attributesFor(
    FcPhotoMetadata meta, {
    bool android = true,
  }) {
    final at = meta.capturedAt;
    final date = _exifDate.format(at);
    final offset = _offset(at.timeZoneOffset);
    final subSec = at.millisecond.toString().padLeft(3, '0');

    final attributes = <String, Object>{
      'DateTime': date,
      'DateTimeOriginal': date,
      'DateTimeDigitized': date,
      'OffsetTime': offset,
      'OffsetTimeOriginal': offset,
      'OffsetTimeDigitized': offset,
      'SubSecTime': subSec,
      'SubSecTimeOriginal': subSec,
      'SubSecTimeDigitized': subSec,
      // Pixels are already upright; omitted, Android writes an invalid 0.
      'Orientation': android ? '1' : 1,
      // No EXIF tag exists for a library, and custom tags get dropped.
      'UserComment': _withCharset(_kit, android: android),
    };

    if (_ascii(meta.app?.software) case final software?) {
      attributes['Software'] = software;
    }

    if (meta.imageId case final id?) attributes['ImageUniqueID'] = id;

    if (meta.hasUser) {
      final artist = [
        meta.userName,
        meta.userId,
        meta.userRole,
        meta.userBranch,
      ].whereType<String>().join(' | ');
      if (_ascii(artist) case final value?) attributes['Artist'] = value;
    }

    if (_ascii(meta.deviceMake) case final make?) attributes['Make'] = make;
    if (_ascii(meta.deviceModel) case final model?) attributes['Model'] = model;

    final location = meta.location;
    if (location != null) {
      // Signed decimals, not DMS; both platforms derive N/S and E/W refs.
      attributes
        ..['GPSLatitude'] = location.latitude
        ..['GPSLongitude'] = location.longitude
        ..['GPSMapDatum'] = 'WGS-84';

      // ExifInterface maps each char to a byte: version 2.3.0.0.
      if (android) attributes['GPSVersionID'] = '\x02\x03\x00\x00';

      if (location.isMocked) {
        attributes['GPSProcessingMethod'] = _withCharset(
          'MOCKED',
          android: android,
        );
      }

      // Android's ExifInterface only parses rationals as "n/d".
      final accuracy = location.accuracyMeters;
      if (accuracy != null && accuracy.isFinite && accuracy >= 0) {
        attributes['GPSHPositioningError'] = android
            ? '${(accuracy * 100).round()}/100'
            : accuracy;
      }

      // UTC, per the spec.
      final fixedAt = location.fixedAt?.toUtc();
      if (fixedAt != null) {
        attributes
          ..['GPSDateStamp'] = _gpsDate.format(fixedAt)
          ..['GPSTimeStamp'] = _gpsTime.format(fixedAt);
      }

      // No altitude: platforms report ellipsoid height, EXIF means sea level.

      // EXIF has no place tag; ImageDescription is the one readers show.
      if (_ascii(location.address) case final address?) {
        attributes['ImageDescription'] = location.isMocked
            ? '$address ${FcGeoLocation.mockedMark}'
            : address;
      }
    }

    return attributes;
  }

  // Spec needs an 8-byte charset prefix; Android omits it, iOS adds its own.
  static String _withCharset(String text, {required bool android}) =>
      android ? 'ASCII\x00\x00\x00$text' : text;

  /// Formats as `+05:30`.
  static String _offset(Duration offset) {
    final minutes = offset.inMinutes.abs();
    final sign = offset.isNegative ? '-' : '+';
    return '$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  // Non-ASCII is dropped; Android would write it as '?'.
  static String? _ascii(String? value) =>
      value == null ||
          value.isEmpty ||
          value.codeUnits.any((unit) => unit > 0x7F)
      ? null
      : value;
}
