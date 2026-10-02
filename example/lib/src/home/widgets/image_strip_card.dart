import 'dart:io';

import 'package:flutter/material.dart';

import 'section_card.dart';
import 'stamp_viewer.dart';

/// A labelled, horizontally scrolling row of image thumbnails.
class ImageStripCard extends StatelessWidget {
  const ImageStripCard({
    required this.label,
    required this.paths,
    required this.viewerTitle,
    super.key,
  });

  final String label;
  final List<String> paths;
  final String viewerTitle;

  static const _tile = 100.0;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SectionCard(
        label: label,
        trailing: Text(
          '${paths.length}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: SizedBox(
          height: _tile + 28,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            itemCount: paths.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _Thumb(
              path: paths[index],
              size: _tile,
              onTap: () =>
                  openStampViewer(context, paths[index], title: viewerTitle),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path, required this.size, required this.onTap});

  final String path;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Decode at tile size, not the full photo.
          cacheWidth: cacheSize,
          // Every result writes a new path; keying on it stops Flutter
          // serving a previous image from its cache.
          key: ValueKey(path),
          errorBuilder: (_, _, _) => SizedBox(
            width: size,
            height: size,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}
