import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../error/fc_camera_exception.dart';

/// Saves processed images where they survive an upload retry.
abstract final class FcImageStore {
  static int _sequence = 0;

  /// Writes into the app documents directory, not temp: the OS may purge temp
  /// at any moment.
  static Future<File> save(Uint8List bytes) async {
    try {
      final directory = Directory(
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'fc_camera_kit',
        ),
      );
      await directory.create(recursive: true);

      // Sequence keeps names unique when several pages finish in the same ms.
      final name = 'fc_${DateTime.now().millisecondsSinceEpoch}_${_sequence++}';
      final file = File(p.join(directory.path, '$name.jpg'));
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (error, stackTrace) {
      throw StorageException(
        'Could not save the processed image.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // Already gone or not ours to delete; neither should fail the caller.
    }
  }
}
