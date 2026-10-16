import 'dart:io';

import 'package:flutter/material.dart';
import 'package:native_exif/native_exif.dart';
import 'package:share_plus/share_plus.dart';

/// Shows a photo or scanned page full screen.
Future<void> openStampViewer(
  BuildContext context,
  String path, {
  String title = 'Stamped photo',
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => StampViewer(path: path, title: title),
    ),
  );
}

/// Zoomable full-resolution view where the stamp is legible.
/// Share and EXIF actions show the stamp and metadata both survive.
class StampViewer extends StatelessWidget {
  const StampViewer({
    required this.path,
    this.title = 'Stamped photo',
    super.key,
  });

  final String path;
  final String title;

  /// Surfaces share failures instead of leaving them in the console.
  Future<void> _share(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], subject: title),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
            content: Text('Could not share: $error'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Embedded metadata',
            onPressed: () => _showMetadata(context, path),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: () => _share(context),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 6,
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            key: ValueKey(path),
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image_outlined, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Tags Android's bulk `getAttributes` omits; they are read one by one.
const _readSeparately = ['ImageDescription', 'OffsetTimeOriginal'];

/// Reads tags back from disk, proving the write actually landed.
Future<Map<String, Object>> _readExif(String path) async {
  final exif = await Exif.fromPath(path);
  try {
    final tags = Map<String, Object>.from(await exif.getAttributes() ?? {});

    for (final tag in _readSeparately) {
      if (tags.containsKey(tag)) continue;

      final value = await exif.getAttribute<String>(tag);
      if (value != null && value.isNotEmpty) tags[tag] = value;
    }

    return tags;
  } finally {
    await exif.close();
  }
}

void _showMetadata(BuildContext context, String path) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) =>
          _MetadataSheet(path: path, controller: controller),
    ),
  );
}

class _MetadataSheet extends StatelessWidget {
  const _MetadataSheet({required this.path, required this.controller});

  final String path;
  final ScrollController controller;

  /// Written tags with friendly labels; place lives in `ImageDescription`.
  static const _written = <String, String>{
    'DateTimeOriginal': 'Taken',
    'OffsetTimeOriginal': 'Time zone',
    'Artist': 'Captured by',
    'Make': 'Maker',
    'Model': 'Device',
    'ImageDescription': 'Place',
    'GPSLatitude': 'Latitude',
    'GPSLongitude': 'Longitude',
    'GPSProcessingMethod': 'Location source',
    'Software': 'App',
    'ImageUniqueID': 'Photo ID',
    'UserComment': 'Written by',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, Object>>(
      future: _readExif(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        // A failed read means the file has no readable EXIF; show that.
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not read EXIF: ${snapshot.error}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          );
        }

        final tags = snapshot.data ?? const <String, Object>{};
        // Kit tags first, in declared order, then whatever the camera wrote.
        final order = _written.keys.toList();
        final keys = tags.keys.toList()
          ..sort((a, b) {
            final ia = order.indexOf(a);
            final ib = order.indexOf(b);
            if (ia != -1 && ib != -1) return ia.compareTo(ib);
            if (ia != -1) return -1;
            if (ib != -1) return 1;
            return a.compareTo(b);
          });

        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              'Embedded metadata',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tags.isEmpty
                  ? 'No EXIF found in this file.'
                  : 'Read back from the file — highlighted rows were written '
                        'by fc_camera_kit.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final key in keys)
              _TagRow(
                name: _written[key] ?? key,
                value: '${tags[key]}',
                ours: _written.containsKey(key),
              ),
          ],
        );
      },
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.name, required this.value, required this.ours});

  final String name;
  final String value;
  final bool ours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ours ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: ours ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
