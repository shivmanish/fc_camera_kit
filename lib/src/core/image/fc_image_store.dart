import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../error/fc_camera_exception.dart';

/// Persists processed images so they outlive an upload retry.
abstract final class FcImageStore {
  static int _sequence = 0;

  // Documents dir, not temp: the OS may purge temp at any time.
  static Future<File> save(Uint8List bytes) async {
    try {
      final directory = Directory(
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'fc_camera_kit',
        ),
      );
      await directory.create(recursive: true);

      // Counter avoids name clashes within the same millisecond.
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
      // Missing or locked files must not fail the caller.
    }
  }
}
