import 'package:intl/intl.dart' show DateFormat;
import 'package:meta/meta.dart';
import 'package:native_exif/native_exif.dart';

import '../../error/fc_camera_exception.dart';
import 'fc_photo_metadata.dart';

/// Writes the resolved metadata into the file's EXIF.
///
/// **Runs last in the pipeline.** Re-encoding an image discards its EXIF, so
/// writing before the JPEG encode would silently lose everything.
abstract final class FcExifWriter {
  /// EXIF's own date format. Not configurable — readers expect exactly this.
  static final _exifDate = DateFormat('yyyy:MM:dd HH:mm:ss');

  static Future<void> write(String path, FcPhotoMetadata meta) async {
    Exif? exif;
    try {
      exif = await Exif.fromPath(path);
      await exif.writeAttributes(attributesFor(meta));
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

  /// The tag map. Pure, so the encoding rules are testable without a file.
  @visibleForTesting
  static Map<String, Object> attributesFor(FcPhotoMetadata meta) {
    final stamped = _exifDate.format(meta.capturedAt);

    // Every value must be a String, except GPS latitude/longitude which must
    // be a double. `native_exif` casts blindly to String on Android and passes
    // values straight through on iOS, so a wrong type is a runtime crash on
    // one platform and silent corruption on the other.
    //
    // Orientation is deliberately absent: compression strips EXIF entirely and
    // the canvas has already baked rotation into the pixels, so there is no
    // stale tag to correct — and the two platforms disagree on its type.
    final attributes = <String, Object>{
      'DateTime': stamped,
      'Software': 'fc_camera_kit',
    };

    // Name and id together in Artist, so one standard field identifies the
    // person completely and no reader has to know about a custom tag.
    if (meta.hasUser) {
      attributes['Artist'] = [
        meta.userName,
        meta.userId,
      ].whereType<String>().join(' | ');
    }

    if (meta.deviceModel != null) attributes['Model'] = meta.deviceModel!;

    // UserComment, because it is the one Exif-IFD text tag both platforms
    // write: native_exif puts every non-GPS key in the Exif dictionary on iOS.
    if (meta.appId != null) attributes['UserComment'] = meta.appId!;

    final location = meta.location;
    if (location != null) {
      // Decimal degrees as doubles, not a DMS rational string: Android parses
      // these with toDouble() and iOS stores them as numbers. Altitude is
      // omitted because the two platforms want incompatible types for it.
      // Signed decimals. The hemisphere refs are not written here: on Android
      // setLatLong derives and writes them from the sign, so setting them
      // ourselves only duplicated what the platform already did.
      attributes
        ..['GPSLatitude'] = location.latitude
        ..['GPSLongitude'] = location.longitude;

      // The place in words — the same text the stamp shows. Stored as
      // ImageDescription because EXIF has no "Place" tag: a made-up tag name
      // is silently dropped by Android's ExifInterface, which only recognises
      // the standard set. Readers display this one.
      final address = location.address;
      if (address != null && address.isNotEmpty) {
        attributes['ImageDescription'] = address;
      }
    }

    return attributes;
  }
}
