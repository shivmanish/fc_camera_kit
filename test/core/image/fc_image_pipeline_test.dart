import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> solidPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width * 1.0, height * 1.0),
    ui.Paint()..color = const ui.Color(0xFF3366AA),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('fc_pipe'));
  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<XFile> fileOf(List<int> bytes) async {
    final file = File('${temp.path}/in.png');
    await file.writeAsBytes(bytes);
    return XFile(file.path);
  }

  group('planFor', () {
    test('lists only the steps that will run, in order', () {
      expect(FcImageStage.planFor(stamp: true, writeMetadata: true), [
        FcImageStage.stamping,
        FcImageStage.compressing,
        FcImageStage.writingMetadata,
      ]);
      expect(FcImageStage.planFor(stamp: false, writeMetadata: true), [
        FcImageStage.compressing,
        FcImageStage.writingMetadata,
      ]);
      expect(FcImageStage.planFor(stamp: true, writeMetadata: false), [
        FcImageStage.stamping,
        FcImageStage.compressing,
      ]);
      expect(FcImageStage.planFor(stamp: false, writeMetadata: false), [
        FcImageStage.compressing,
      ]);
    });

    test('the scanner names are aliases of the shared ones', () {
      expect(FcScanStage.stamping, same(FcImageStage.stamping));
      expect(
        const FcScanStamp(
          placement: StampPlacement.overlay,
          dateFormat: 'yyyy',
        ),
        isA<FcStampSpec>(),
      );
    });
  });

  group('run', () {
    test('a missing source is a StorageException', () async {
      expect(
        () => FcImagePipeline.run(
          XFile('${temp.path}/missing.png'),
          maxBytes: 1000,
        ),
        throwsA(isA<StorageException>()),
      );
    });

    test(
      'a source that is not an image is an ImageProcessingException',
      () async {
        final source = await fileOf(List.filled(64, 7));

        expect(
          () => FcImagePipeline.run(source, maxBytes: 1000),
          throwsA(isA<ImageProcessingException>()),
        );
      },
    );

    test('reports stamping before compressing when stamping', () async {
      final source = await fileOf(await solidPng(60, 40));
      final stages = <FcImageStage>[];

      // No compressor plugin in tests: the run stops at compression, after
      // the stamp has been rendered and both stages reported.
      await expectLater(
        FcImagePipeline.run(
          source,
          maxBytes: 100000,
          metadata: FcPhotoMetadata(capturedAt: DateTime(2026, 10, 2)),
          stamp: const FcStampSpec(
            placement: StampPlacement.overlay,
            dateFormat: 'dd MMM yyyy',
          ),
          onStage: stages.add,
        ),
        throwsA(isA<ImageProcessingException>()),
      );
      expect(stages, [FcImageStage.stamping, FcImageStage.compressing]);
    });

    test('skips stamping without metadata to stamp', () async {
      final source = await fileOf(await solidPng(60, 40));
      final stages = <FcImageStage>[];

      await expectLater(
        FcImagePipeline.run(
          source,
          maxBytes: 100000,
          stamp: const FcStampSpec(
            placement: StampPlacement.overlay,
            dateFormat: 'dd MMM yyyy',
          ),
          onStage: stages.add,
        ),
        throwsA(isA<ImageProcessingException>()),
      );
      expect(stages, [FcImageStage.compressing]);
    });
  });
}
