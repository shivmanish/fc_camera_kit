import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:fc_camera_kit/src/features/scanner/data/datasources/fc_scan_engine.dart';
import 'package:fc_camera_kit/src/features/scanner/data/repositories/fc_scan_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEngine extends Mock implements FcScanEngine {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockEngine engine;
  late FcScanRepositoryImpl repository;
  late Directory temp;

  const options = FcScanOptions(maxPages: 3);

  setUpAll(() => registerFallbackValue(options));

  setUp(() async {
    engine = _MockEngine();
    when(() => engine.clearCache()).thenAnswer((_) async {});
    repository = FcScanRepositoryImpl(engine: engine);
    temp = await Directory.systemTemp.createTemp('fc_scan_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<File> tempFile(String name, [List<int> bytes = const [1, 2, 3]]) =>
      File('${temp.path}/$name').writeAsBytes(bytes);

  group('acquire', () {
    test('wraps every returned path as an XFile, in order', () async {
      when(
        () => engine.scan(options),
      ).thenAnswer((_) async => ['/a.jpg', '/b.jpg']);

      final result = await repository.acquire(options);

      expect(result.valueOrNull?.map((file) => file.path), [
        '/a.jpg',
        '/b.jpg',
      ]);
    });

    test('passes the options through to the engine unchanged', () async {
      when(() => engine.scan(any())).thenAnswer((_) async => ['/a.jpg']);

      await repository.acquire(options);

      verify(() => engine.scan(options)).called(1);
    });

    test('treats a null result as a cancel', () async {
      when(() => engine.scan(options)).thenAnswer((_) async => null);

      final result = await repository.acquire(options);

      expect(result.failureOrNull, isA<CancelledFailure>());
    });

    test('treats an empty result as a cancel', () async {
      when(() => engine.scan(options)).thenAnswer((_) async => []);

      final result = await repository.acquire(options);

      expect(result.failureOrNull, isA<CancelledFailure>());
    });

    test('maps a permission denial to a camera PermissionFailure', () async {
      when(
        () => engine.scan(options),
      ).thenThrow(const PermissionException('denied', permanentlyDenied: true));

      final failure = (await repository.acquire(options)).failureOrNull;

      expect(
        failure,
        isA<PermissionFailure>()
            .having((f) => f.permission, 'permission', 'camera')
            .having((f) => f.permanentlyDenied, 'permanentlyDenied', true),
      );
    });

    test('maps a scanner crash to a CameraFailure', () async {
      when(
        () => engine.scan(options),
      ).thenThrow(const CameraException('scanner died'));

      final failure = (await repository.acquire(options)).failureOrNull;

      expect(failure, const CameraFailure('scanner died'));
    });

    test('never throws on an unexpected error', () async {
      when(() => engine.scan(options)).thenThrow(StateError('boom'));

      final failure = (await repository.acquire(options)).failureOrNull;

      expect(failure, isA<UnknownFailure>());
    });
  });

  group('process', () {
    test('reports a missing page file as a StorageFailure', () async {
      final result = await repository.process(
        XFile('${temp.path}/missing.jpg'),
        maxBytes: 1000,
      );

      expect(result.failureOrNull, isA<StorageFailure>());
    });

    test(
      'reports a page that is not an image as an ImageProcessingFailure',
      () async {
        final garbage = await tempFile(
          'garbage.jpg',
          Uint8List.fromList(List.filled(64, 7)),
        );

        final result = await repository.process(
          XFile(garbage.path),
          maxBytes: 1000,
        );

        expect(result.failureOrNull, isA<ImageProcessingFailure>());
      },
    );
  });

  group('discard', () {
    test('deletes produced pages and clears the scanner cache', () async {
      final a = await tempFile('a.jpg');
      final b = await tempFile('b.jpg');

      await repository.discard(
        pages: [
          for (final file in [a, b])
            FcScannedPage(
              file: XFile(file.path),
              sizeBytes: 3,
              width: 1,
              height: 1,
              wasCompressed: false,
              quality: 90,
            ),
        ],
      );

      expect(await a.exists(), isFalse);
      expect(await b.exists(), isFalse);
      verify(() => engine.clearCache()).called(1);
    });

    test('does not fail when a page file is already gone', () async {
      await expectLater(
        repository.discard(
          pages: [
            FcScannedPage(
              file: XFile('${temp.path}/gone.jpg'),
              sizeBytes: 0,
              width: 1,
              height: 1,
              wasCompressed: false,
              quality: 90,
            ),
          ],
        ),
        completes,
      );
      verify(() => engine.clearCache()).called(1);
    });
  });

  test('clearCache delegates to the engine', () async {
    await repository.clearCache();

    verify(() => engine.clearCache()).called(1);
  });
}
