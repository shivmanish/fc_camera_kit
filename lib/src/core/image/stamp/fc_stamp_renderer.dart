import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:meta/meta.dart';

import '../../config/fc_camera_kit.dart';
import '../../error/fc_camera_exception.dart';
import '../edit/fc_photo_edit.dart';
import '../edit/fc_photo_editor.dart';
import '../fc_bmp_encoder.dart';
import '../metadata/fc_geo_location.dart';
import '../metadata/fc_photo_metadata.dart';
import 'fc_stamp_style.dart';

/// Draws who / when / where onto a photo, returning lossless pixels.
abstract final class FcStampRenderer {
  static Future<FcStampedImage> render({
    required Uint8List source,
    required FcPhotoMetadata metadata,
    required StampPlacement placement,
    required String dateFormat,
    bool includeDevice = false,
    FcStampStyle style = const FcStampStyle(),
    FcPhotoEdit edit = FcPhotoEdit.none,
  }) async {
    final image = await _edited(await _decode(source), edit);

    try {
      final lines = buildLines(
        metadata,
        dateFormat,
        includeDevice: includeDevice,
      );
      if (lines.isEmpty) {
        return FcStampedImage(
          bytes: await _encodePixels(image),
          width: image.width,
          height: image.height,
        );
      }

      final width = image.width.toDouble();
      final height = image.height.toDouble();
      final targetWidth = placement == StampPlacement.overlay
          ? width * style.overlayMaxWidthRatio
          : width;

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
        // Hug the text so short lines don't get a full-width band.
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

  // Redraws just the strip through a blur, then tints it.
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
          meta.userRole,
          meta.userBranch,
        ].where((part) => part != null && part.isNotEmpty).join('  ·  '),
      );
    }

    lines.add(DateFormat(dateFormat).format(meta.capturedAt));

    final location = meta.location;
    if (location != null) {
      final address = location.address;
      // Mocked fixes stay, but are visibly marked.
      final mocked = location.isMocked ? ' ${FcGeoLocation.mockedMark}' : '';
      lines.add(
        address == null || address.isEmpty
            ? '(${location.coordinates})$mocked'
            : '$address  ·  (${location.coordinates})$mocked',
      );
    }

    final device = [
      meta.deviceMake,
      meta.deviceModel,
    ].whereType<String>().join(' | ');
    if (includeDevice && device.isNotEmpty) lines.add(device);

    if (meta.app case final app?) lines.add(app.stampLine);

    if (meta.note != null && meta.note!.isNotEmpty) lines.add(meta.note!);

    return lines;
  }

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

  // Width is ~linear in size: solve from one reference measurement, then
  // one rescale pass corrects the ~1% hinting error.
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

  // Measured at the drawn weight; bold is wider.
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

  static Future<ui.Image> _edited(ui.Image image, FcPhotoEdit edit) async {
    if (edit.isNone) return image;
    try {
      return await FcPhotoEditor.apply(image, edit);
    } finally {
      image.dispose();
    }
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

  static Future<Uint8List> _encodePixels(ui.Image image) async {
    // Default rawRgba is a plain readback; png would deflate needlessly.
    final data = await image.toByteData();
    if (data == null) {
      throw const ImageProcessingException('Stamped image read back as null.');
    }

    // Per-pixel loop runs off the UI isolate; pass only plain values.
    final rgba = data.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    return Isolate.run(() => FcBmpEncoder.encode(rgba, width, height));
  }
}

final class FcStampedImage {
  const FcStampedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;

  final int width;
  final int height;
}
