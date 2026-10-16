import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../presentation/molecules/fc_step_list.dart';
import '../../domain/entities/fc_scan_stage.dart';

/// Progress from scanner close to result; the spinner never restarts.
class FcScanPreparingView extends StatelessWidget {
  const FcScanPreparingView({
    this.imagePath,
    this.page,
    this.total,
    this.stages = const [],
    this.stage,
    super.key,
  });

  /// `null` while the platform scanner is open.
  final String? imagePath;
  final int? page;
  final int? total;
  final List<FcScanStage> stages;
  final FcScanStage? stage;

  static const _fade = Duration(milliseconds: 250);
  static const _spinner = 44.0;

  @override
  Widget build(BuildContext context) {
    final imagePath = this.imagePath;
    final page = this.page;
    final total = this.total;

    // Always dark to match the scanner and keep white text readable.
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: _fade,
            child: imagePath == null
                ? const SizedBox.expand()
                : _PageImage(key: ValueKey(imagePath), path: imagePath),
          ),
          AnimatedOpacity(
            opacity: imagePath == null ? 0 : 1,
            duration: _fade,
            child: const ColoredBox(color: Color(0x99000000)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                // Centred, so it grows smoothly when details arrive.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: _spinner,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                    AnimatedSize(
                      duration: _fade,
                      curve: Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                        duration: _fade,
                        child: page == null || total == null
                            ? const SizedBox(width: double.infinity)
                            : _Details(
                                page: page,
                                total: total,
                                stages: stages,
                                stage: stage,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageImage extends StatelessWidget {
  const _PageImage({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ratio = MediaQuery.devicePixelRatioOf(context);

    return Image.file(
      File(path),
      fit: BoxFit.contain,
      // Decode at display size, not full resolution.
      cacheWidth: (width * ratio).round(),
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.page,
    required this.total,
    required this.stages,
    required this.stage,
  });

  final int page;
  final int total;
  final List<FcScanStage> stages;
  final FcScanStage? stage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = total > 1
        ? 'Preparing page $page of $total'
        : 'Preparing scan';
    final stage = this.stage;

    return Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep the app open',
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xB3FFFFFF),
            ),
          ),
          if (stages.isNotEmpty) ...[
            const SizedBox(height: 24),
            FcStepList(
              labels: [for (final step in stages) step.label],
              // Show the first stage running until one is reported.
              current: stage == null ? 0 : stages.indexOf(stage),
            ),
          ],
        ],
      ),
    );
  }
}
