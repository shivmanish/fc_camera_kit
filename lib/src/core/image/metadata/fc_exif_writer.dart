import 'dart:io' show Platform;
import 'dart:math' show Random;

import 'package:intl/intl.dart' show DateFormat;
import 'package:meta/meta.dart';
import 'package:native_exif/native_exif.dart';

import '../../error/fc_camera_exception.dart';
import 'fc_geo_location.dart';
import 'fc_photo_metadata.dart';

/// Writes the resolved metadata into the file's EXIF.
///
/// **Runs last in the pipeline.** Re-encoding an image discards its EXIF, so
/// writing before the JPEG encode would silently lose everything.
abstract final class FcExifWriter {
  /// Held back from the compression budget for the EXIF block, so the
  /// finished file — not just the pixels — stays under the ceiling. The block
  /// itself is about 1 KB.
  static const reservedBytes = 4 * 1024;

  /// EXIF's own date formats. Not configurable — readers expect exactly these.
  static final _exifDate = DateFormat('yyyy:MM:dd HH:mm:ss');
  static final _gpsDate = DateFormat('yyyy:MM:dd');
  static final _gpsTime = DateFormat('HH:mm:ss');

  static const _kit = 'fc_camera_kit';

  /// Writes [meta] into the file at [path] under a fresh photo id, and returns
  /// the metadata as written, id included.
  static Future<FcPhotoMetadata> write(
    String path,
    FcPhotoMetadata meta,
  ) async {
    // Fresh per file, even when one metadata serves several pages.
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

  /// A random UUID v4 as 32 lowercase hex digits — the form EXIF
  /// `ImageUniqueID` takes. Add the dashes back for a UUID column.
  @visibleForTesting
  static String newImageId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = bytes[6] & 0x0F | 0x40; // version 4
    bytes[8] = bytes[8] & 0x3F | 0x80; // RFC 4122 variant
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// The tag map. Pure, so the encoding rules are testable without a file.
  ///
  /// [android] picks the value types. `native_exif` casts every value to a
  /// String on Android, except GPS latitude/longitude which it parses as a
  /// double, and passes values straight through to ImageIO on iOS, which
  /// wants numbers for numeric tags. A wrong type is a runtime crash on one
  /// platform and silent corruption on the other.
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
      // One moment, three tags: DateTimeOriginal is what galleries and
      // backends sort by, and the offsets make the local time unambiguous.
      'DateTime': date,
      'DateTimeOriginal': date,
      'DateTimeDigitized': date,
      'OffsetTime': offset,
      'OffsetTimeOriginal': offset,
      'OffsetTimeDigitized': offset,
      'SubSecTime': subSec,
      'SubSecTimeOriginal': subSec,
      'SubSecTimeDigitized': subSec,
      // The canvas has already baked rotation into the pixels, so they are
      // upright. Left out, Android's ExifInterface writes 0, an invalid value.
      'Orientation': android ? '1' : 1,
      // The kit, best effort: EXIF has no tag for a library, and a made-up
      // tag is dropped. UserComment is the standard free-text note, so it
      // outlives most re-saves.
      'UserComment': _withCharset(_kit, android: android),
    };

    // The standard tag for what made the image: the host app and its build.
    if (_ascii(meta.app?.software) case final software?) {
      attributes['Software'] = software;
    }

    // One id per file, so a backend can match a file to its record and spot
    // the same photo uploaded twice.
    if (meta.imageId case final id?) attributes['ImageUniqueID'] = id;

    // Name, id, role and branch together in Artist, so one standard field
    // identifies the person completely and no reader has to know about a
    // custom tag.
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
      // Decimal degrees as doubles, not a DMS rational string: Android parses
      // these with toDouble() and iOS stores them as numbers. Signed decimals:
      // both platforms derive the N/S and E/W refs from the sign.
      attributes
        ..['GPSLatitude'] = location.latitude
        ..['GPSLongitude'] = location.longitude
        // The datum the platforms report coordinates in.
        ..['GPSMapDatum'] = 'WGS-84';

      // Required in a GPS block by the standard. ExifInterface turns each
      // character into one byte, so these are the raw version bytes 2.3.0.0.
      if (android) attributes['GPSVersionID'] = '\x02\x03\x00\x00';

      // A fix from a mock-location app is kept but called out, in the
      // standard tag for how the position was found.
      if (location.isMocked) {
        attributes['GPSProcessingMethod'] = _withCharset(
          'MOCKED',
          android: android,
        );
      }

      // How far off the fix may be, in metres. Android's ExifInterface only
      // parses rationals as "numerator/denominator".
      final accuracy = location.accuracyMeters;
      if (accuracy != null && accuracy.isFinite && accuracy >= 0) {
        attributes['GPSHPositioningError'] = android
            ? '${(accuracy * 100).round()}/100'
            : accuracy;
      }

      // When the fix was taken, in UTC as the standard requires. Older than
      // the photo when the last known position stood in for a fresh fix.
      final fixedAt = location.fixedAt?.toUtc();
      if (fixedAt != null) {
        attributes
          ..['GPSDateStamp'] = _gpsDate.format(fixedAt)
          ..['GPSTimeStamp'] = _gpsTime.format(fixedAt);
      }

      // Altitude is left out: the platforms report height above the WGS-84
      // ellipsoid, while EXIF means sea level — tens of metres apart.

      // The place in words — the same text the stamp shows. Stored as
      // ImageDescription because EXIF has no "Place" tag: a made-up tag name
      // is silently dropped by Android's ExifInterface, which only recognises
      // the standard set. Readers display this one.
      if (_ascii(location.address) case final address?) {
        attributes['ImageDescription'] = location.isMocked
            ? '$address ${FcGeoLocation.mockedMark}'
            : address;
      }
    }

    return attributes;
  }

  /// UserComment and GPSProcessingMethod open with an 8-byte charset header,
  /// by the standard. Android's ExifInterface leaves it out, so it is spelled
  /// out here; iOS writes its own.
  static String _withCharset(String text, {required bool android}) =>
      android ? 'ASCII\x00\x00\x00$text' : text;

  /// `+05:30` — the form EXIF's OffsetTime tags take.
  static String _offset(Duration offset) {
    final minutes = offset.inMinutes.abs();
    final sign = offset.isNegative ? '-' : '+';
    return '$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// EXIF text tags are 7-bit ASCII, and Android's ExifInterface writes
  /// anything else as '?'. A value that does not fit is left out rather than
  /// stored as garbage; the stamp still shows it.
  static String? _ascii(String? value) =>
      value == null ||
          value.isEmpty ||
          value.codeUnits.any((unit) => unit > 0x7F)
      ? null
      : value;
}
