import 'dart:typed_data';

import 'package:fc_camera_kit/src/features/camera/data/datasources/fc_frame_snapshot.dart';
import 'package:fc_camera_kit/src/features/camera/domain/entities/fc_camera_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A BGRA frame whose pixel at (x, y) has red = its index in [labels].
  FcCameraFrame bgra(List<List<int>> rows, {int rotation = 0}) {
    final height = rows.length;
    final width = rows.first.length;
    final bytes = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        bytes[i + 2] = rows[y][x]; // red
        bytes[i + 3] = 255;
      }
    }
    return FcCameraFrame(
      bytes: bytes,
      width: width,
      height: height,
      bytesPerRow: width * 4,
      rotationDegrees: rotation,
      format: FcFrameFormat.bgra8888,
    );
  }

  /// The red channel of the result, as rows.
  List<List<int>> reds(FcFramePixels pixels) => [
    for (var y = 0; y < pixels.height; y++)
      [
        for (var x = 0; x < pixels.width; x++)
          pixels.rgba[(y * pixels.width + x) * 4],
      ],
  ];

  final source = [
    [1, 2, 3],
    [4, 5, 6],
  ];

  test('0°: unchanged', () {
    expect(reds(FcFrameSnapshot.toRgba(bgra(source))), source);
  });

  test('90° clockwise: the left column becomes the top row', () {
    expect(reds(FcFrameSnapshot.toRgba(bgra(source, rotation: 90))), [
      [4, 1],
      [5, 2],
      [6, 3],
    ]);
  });

  test('180°: upside down', () {
    expect(reds(FcFrameSnapshot.toRgba(bgra(source, rotation: 180))), [
      [6, 5, 4],
      [3, 2, 1],
    ]);
  });

  test('270° clockwise: the right column becomes the top row', () {
    expect(reds(FcFrameSnapshot.toRgba(bgra(source, rotation: 270))), [
      [3, 6],
      [2, 5],
      [1, 4],
    ]);
  });

  test('mirror flips left and right after rotating upright', () {
    expect(
      reds(FcFrameSnapshot.toRgba(bgra(source, rotation: 90), mirror: true)),
      [
        [1, 4],
        [2, 5],
        [3, 6],
      ],
    );
  });

  test('NV21 grey converts to the same grey, fully opaque', () {
    const width = 4;
    const height = 2;
    final bytes = Uint8List(width * height * 3 ~/ 2)
      ..fillRange(0, width * height, 120)
      ..fillRange(width * height, width * height * 3 ~/ 2, 128);
    final pixels = FcFrameSnapshot.toRgba(
      FcCameraFrame(
        bytes: bytes,
        width: width,
        height: height,
        bytesPerRow: width,
        rotationDegrees: 270,
        format: FcFrameFormat.nv21,
      ),
    );

    expect((pixels.width, pixels.height), (2, 4));
    expect(pixels.rgba.sublist(0, 4), [120, 120, 120, 255]);
  });

  test('NV21 red chroma comes out red', () {
    const width = 2;
    const height = 2;
    // Y = 76, V (Cr) = 255, U (Cb) = 85: pure red in full-range YUV.
    final bytes = Uint8List.fromList([76, 76, 76, 76, 255, 85]);
    final pixels = FcFrameSnapshot.toRgba(
      FcCameraFrame(
        bytes: bytes,
        width: width,
        height: height,
        bytesPerRow: width,
        rotationDegrees: 0,
        format: FcFrameFormat.nv21,
      ),
    );

    expect(pixels.rgba[0], greaterThan(240));
    expect(pixels.rgba[1], lessThan(20));
    expect(pixels.rgba[2], lessThan(20));
  });
}
