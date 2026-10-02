import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:meta/meta.dart';

import '../../config/fc_camera_kit.dart';
import '../../error/fc_camera_exception.dart';
import '../fc_bmp_encoder.dart';
import '../metadata/fc_photo_metadata.dart';
import 'fc_stamp_style.dart';

/// Burns the who/when/where lines into the pixels.
///
/// Uses `dart:ui` rather than a pure-Dart encoder: only a real [ui.Canvas]
/// gives proper text layout and a Gaussian blur, and it runs on the GPU.
///
/// Returns **PNG** bytes. That is deliberate — `toByteData` encodes nothing
/// else, and handing lossless pixels to the compressor means the only lossy
/// step in the whole pipeline is the final JPEG encode.
abstract final class FcStampRenderer {
  static Future<FcStampedImage> render({
    required Uint8List source,
    required FcPhotoMetadata metadata,
    required StampPlacement placement,
    required String dateFormat,
    bool includeDevice = false,
    FcStampStyle style = const FcStampStyle(),
  }) async {
    final image = await _decode(source);

    try {
      final lines = buildLines(
        metadata,
        dateFormat,
        includeDevice: includeDevice,
      );
      if (lines.isEmpty) {
        // Nothing to say, but the caller still needs pixels and dimensions.
        return FcStampedImage(
          bytes: await _encodePixels(image),
          width: image.width,
          height: image.height,
        );
      }

      final width = image.width.toDouble();
      final height = image.height.toDouble();
      // Overlay takes a fraction of the frame; extend owns its panel and can
      // use the full width.
      final targetWidth = placement == StampPlacement.overlay
          ? width * style.overlayMaxWidthRatio
          : width;

      // Size the type so the badge lands on that width, rather than picking a
      // point size and hoping.
      final fontSize = fitFontSize(lines, style, targetWidth);
      final insets = style.insetsFor(placement, fontSize);
      final maxStripWidth = targetWidth;
      final painters = _layout(
        lines,
        style,
        fontSize,
        maxStripWidth - insets.horizontal * 2,
      );
      final textHeight = painters.fold<double>(
        0,
        (sum, painter) => sum + painter.height,
      );
      final panelHeight = textHeight + insets.top + insets.bottom;

      final recorder = ui.PictureRecorder();
      final canvasHeight = placement == StampPlacement.extend
          ? height + panelHeight
          : height;
      final canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, width, canvasHeight),
      );

      canvas.drawImage(image, ui.Offset.zero, ui.Paint());

      if (placement == StampPlacement.extend) {
        final panel = ui.Rect.fromLTWH(0, height, width, panelHeight);
        canvas.drawRect(panel, ui.Paint()..color = style.panelColor);
        _paintLines(canvas, painters, insets.horizontal, height + insets.top);
      } else {
        // The narrower of the cap and the text itself, so short lines get
        // short strips instead of a band across the photo.
        final textWidth = painters.fold<double>(
          0,
          (widest, painter) => painter.width > widest ? painter.width : widest,
        );
        final stripWidth = (textWidth + insets.horizontal * 2).clamp(
          0,
          maxStripWidth,
        );

        final panel = ui.Rect.fromLTWH(
          0,
          height - panelHeight,
          stripWidth.toDouble(),
          panelHeight,
        );
        _drawFrostedStrip(canvas, image, panel, style);
        _paintLines(
          canvas,
          painters,
          insets.horizontal,
          panel.top + insets.top,
        );
      }

      return _rasterize(recorder, width.round(), canvasHeight.round());
    } finally {
      image.dispose();
    }
  }

  static void _paintLines(
    ui.Canvas canvas,
    List<TextPainter> painters,
    double left,
    double top,
  ) {
    var dy = top;
    for (final painter in painters) {
      painter.paint(canvas, ui.Offset(left, dy));
      dy += painter.height;
    }
  }

  /// Blurs only the slice of photo sitting behind the text, never the whole
  /// image: draw that region again through a blur filter, then tint it.
  static void _drawFrostedStrip(
    ui.Canvas canvas,
    ui.Image image,
    ui.Rect strip,
    FcStampStyle style,
  ) {
    canvas
      ..save()
      ..clipRect(strip)
      ..drawImageRect(
        image,
        strip,
        strip,
        ui.Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: style.blurSigma,
            sigmaY: style.blurSigma,
            tileMode: ui.TileMode.clamp,
          ),
      )
      ..restore()
      ..drawRect(strip, ui.Paint()..color = style.scrimColor);
  }

  /// The stamp's text, in order. Lines with nothing to show are dropped so a
  /// missing location never leaves a blank row.
  @visibleForTesting
  static List<String> buildLines(
    FcPhotoMetadata meta,
    String dateFormat, {
    bool includeDevice = false,
  }) {
    final lines = <String>[];

    if (meta.hasUser) {
      lines.add(
        [
          meta.userName,
          meta.userId,
        ].where((part) => part != null && part.isNotEmpty).join('  ·  '),
      );
    }

    lines.add(DateFormat(dateFormat).format(meta.capturedAt));

    final location = meta.location;
    if (location != null) {
      final address = location.address;
      lines.add(
        address == null || address.isEmpty
            ? '(${location.coordinates})'
            : '$address  ·  (${location.coordinates})',
      );
    }

    // Always in EXIF, only here when asked for — it is audit data, not
    // something the person looking at the photo needs to read.
    if (includeDevice && meta.deviceModel != null) {
      lines.add(meta.deviceModel!);
    }

    if (meta.note != null && meta.note!.isNotEmpty) lines.add(meta.note!);

    return lines;
  }

  /// First line is the identity and carries the most weight; the rest are
  /// muted so the stamp reads as a hierarchy, not a wall of text.
  static List<TextPainter> _layout(
    List<String> lines,
    FcStampStyle style,
    double fontSize,
    double maxWidth,
  ) {
    return [
      for (var i = 0; i < lines.length; i++)
        TextPainter(
          text: TextSpan(
            text: lines[i],
            style: TextStyle(
              color: i == 0 ? style.textColor : style.mutedTextColor,
              // Same size on every line; hierarchy comes from weight and
              // colour instead, which costs no extra height.
              fontSize: fontSize,
              fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
              height: style.lineSpacing,
              letterSpacing: -0.2,
              shadows: const [Shadow(blurRadius: 3, color: Color(0x99000000))],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '…',
        )..layout(maxWidth: maxWidth),
    ];
  }

  /// Solves for the font size whose longest line, plus horizontal padding,
  /// exactly fills [targetWidth].
  ///
  /// Text width is very nearly linear in point size, so one measurement at a
  /// reference size gives a closed-form first guess:
  ///
  ///     f = target / (widest / ref + 2 x paddingRatio)
  ///
  /// Hinting makes that ~1% out, so a single correction pass re-measures at
  /// the guess and rescales. Two layouts total, no search loop.
  @visibleForTesting
  static double fitFontSize(
    List<String> lines,
    FcStampStyle style,
    double targetWidth,
  ) {
    if (lines.isEmpty) return style.minFontSize;

    const reference = 100.0;
    final referenceWidth = _widestAt(lines, reference);
    if (referenceWidth <= 0) return style.minFontSize;

    var size =
        targetWidth / (referenceWidth / reference + 2 * style.paddingRatio);

    final occupied = _widestAt(lines, size) + 2 * style.paddingFor(size);
    if (occupied > 0) size *= targetWidth / occupied;

    return size.clamp(style.minFontSize, style.maxFontSize);
  }

  /// Width of the longest line at [fontSize], measured at the weight each line
  /// is actually drawn at — bold is wider, and guessing would overflow.
  static double _widestAt(List<String> lines, double fontSize) {
    var widest = 0.0;

    for (var i = 0; i < lines.length; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: lines[i],
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      if (painter.width > widest) widest = painter.width;
    }

    return widest;
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (error, stackTrace) {
      throw ImageProcessingException(
        'Could not decode the source image.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<FcStampedImage> _rasterize(
    ui.PictureRecorder recorder,
    int width,
    int height,
  ) async {
    final picture = recorder.endRecording();
    try {
      final rendered = await picture.toImage(width, height);
      try {
        return FcStampedImage(
          bytes: await _encodePixels(rendered),
          width: width,
          height: height,
        );
      } finally {
        rendered.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  /// Raw pixels wrapped in a BMP. See [FcBmpEncoder] for why not PNG.
  static Future<Uint8List> _encodePixels(ui.Image image) async {
    // rawRgba is toByteData's default, and the point here: it is a plain
    // readback, where ImageByteFormat.png would deflate 45 MB we throw away.
    final data = await image.toByteData();
    if (data == null) {
      throw const ImageProcessingException('Stamped image read back as null.');
    }

    return FcBmpEncoder.encode(
      data.buffer.asUint8List(),
      image.width,
      image.height,
    );
  }
}

/// A stamped frame, still lossless, with its size already known.
///
/// Carrying the dimensions removes a full decode downstream that existed only
/// to re-measure what the renderer already knew.
final class FcStampedImage {
  const FcStampedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  /// An in-memory intermediate for the compressor. Never written to disk.
  final Uint8List bytes;

  final int width;
  final int height;
}
