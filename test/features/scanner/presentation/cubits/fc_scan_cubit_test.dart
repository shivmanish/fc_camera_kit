import 'package:bloc_test/bloc_test.dart';
import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements FcScanRepository {}

void main() {
  late _MockRepository repository;

  const options = FcScanOptions(maxPages: 2);
  const stages = [FcScanStage.compressing, FcScanStage.writingMetadata];
  final rawA = XFile('/raw/a.jpg');
  final rawB = XFile('/raw/b.jpg');
  final pageA = FcScannedPage(
    file: XFile('/out/a.jpg'),
    sizeBytes: 100,
    width: 10,
    height: 20,
    wasCompressed: false,
    quality: 90,
  );
  final pageB = FcScannedPage(
    file: XFile('/out/b.jpg'),
    sizeBytes: 200,
    width: 10,
    height: 20,
    wasCompressed: true,
    quality: 80,
  );

  Future<FcResult<FcPhotoMetadata?>> noMetadata() async => fcSuccess(null);

  setUpAll(() {
    registerFallbackValue(options);
    registerFallbackValue(XFile(''));
  });

  setUp(() {
    repository = _MockRepository();
    when(() => repository.clearCache()).thenAnswer((_) async {});
    when(
      () => repository.discard(pages: any(named: 'pages')),
    ).thenAnswer((_) async {});
  });

  FcScanCubit build() => FcScanCubit(repository: repository);

  Future<void> start(FcScanCubit cubit) => cubit.start(
    options: options,
    maxBytes: 1000,
    resolveMetadata: noMetadata,
  );

  blocTest<FcScanCubit, FcScanState>(
    'processes every page and succeeds',
    setUp: () {
      when(
        () => repository.acquire(any()),
      ).thenAnswer((_) async => fcSuccess([rawA, rawB]));
      when(
        () => repository.process(
          rawA,
          maxBytes: 1000,
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) async => fcSuccess(pageA));
      when(
        () => repository.process(
          rawB,
          maxBytes: 1000,
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) async => fcSuccess(pageB));
    },
    build: build,
    act: start,
    expect: () => [
      const FcScanScanning(),
      FcScanProcessing(page: 1, total: 2, preview: rawA, stages: stages),
      FcScanProcessing(page: 2, total: 2, preview: rawB, stages: stages),
      FcScanSuccess(FcScanResult([pageA, pageB])),
    ],
    verify: (_) => verify(() => repository.clearCache()).called(1),
  );

  blocTest<FcScanCubit, FcScanState>(
    'reports a cancel as CancelledFailure',
    setUp: () => when(
      () => repository.acquire(any()),
    ).thenAnswer((_) async => fcFailure(const CancelledFailure())),
    build: build,
    act: start,
    expect: () => [
      const FcScanScanning(),
      const FcScanError(CancelledFailure()),
    ],
  );

  blocTest<FcScanCubit, FcScanState>(
    'discards finished pages when a later page fails',
    setUp: () {
      when(
        () => repository.acquire(any()),
      ).thenAnswer((_) async => fcSuccess([rawA, rawB]));
      when(
        () => repository.process(
          rawA,
          maxBytes: 1000,
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) async => fcSuccess(pageA));
      when(
        () => repository.process(
          rawB,
          maxBytes: 1000,
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer(
        (_) async => fcFailure(const ImageProcessingFailure('bad page')),
      );
    },
    build: build,
    act: start,
    expect: () => [
      const FcScanScanning(),
      FcScanProcessing(page: 1, total: 2, preview: rawA, stages: stages),
      FcScanProcessing(page: 2, total: 2, preview: rawB, stages: stages),
      const FcScanError(ImageProcessingFailure('bad page')),
    ],
    verify: (_) => verify(() => repository.discard(pages: [pageA])).called(1),
  );

  blocTest<FcScanCubit, FcScanState>(
    'fails without processing when metadata cannot be resolved',
    setUp: () => when(
      () => repository.acquire(any()),
    ).thenAnswer((_) async => fcSuccess([rawA])),
    build: build,
    act: (cubit) => cubit.start(
      options: options,
      maxBytes: 1000,
      resolveMetadata: () async => fcFailure(const LocationFailure('no fix')),
    ),
    expect: () => [
      const FcScanScanning(),
      FcScanProcessing(page: 1, total: 1, preview: rawA, stages: stages),
      const FcScanError(LocationFailure('no fix')),
    ],
    verify: (_) => verifyNever(
      () => repository.process(
        any(),
        maxBytes: any(named: 'maxBytes'),
        metadata: any(named: 'metadata'),
        writeMetadata: any(named: 'writeMetadata'),
        stamp: any(named: 'stamp'),
        onStage: any(named: 'onStage'),
      ),
    ),
  );

  blocTest<FcScanCubit, FcScanState>(
    'ignores a second start while one is running',
    setUp: () => when(
      () => repository.acquire(any()),
    ).thenAnswer((_) async => fcFailure(const CancelledFailure())),
    build: build,
    act: (cubit) async {
      final first = start(cubit);
      await start(cubit);
      await first;
    },
    verify: (_) => verify(() => repository.acquire(any())).called(1),
  );

  blocTest<FcScanCubit, FcScanState>(
    'ends in an error, never stuck, when metadata resolution throws',
    setUp: () => when(
      () => repository.acquire(any()),
    ).thenAnswer((_) async => fcSuccess([rawA])),
    build: build,
    act: (cubit) => cubit.start(
      options: options,
      maxBytes: 1000,
      resolveMetadata: () => throw StateError('platform channel died'),
    ),
    expect: () => [
      const FcScanScanning(),
      FcScanProcessing(page: 1, total: 1, preview: rawA, stages: stages),
      isA<FcScanError>().having(
        (state) => state.failure,
        'failure',
        isA<UnknownFailure>(),
      ),
    ],
    verify: (_) => verify(() => repository.discard(pages: [])).called(1),
  );

  test('discards finished pages when closed mid-processing', () async {
    final cubit = build();
    when(
      () => repository.acquire(any()),
    ).thenAnswer((_) async => fcSuccess([rawA, rawB]));
    when(
      () => repository.process(
        rawA,
        maxBytes: 1000,
        metadata: any(named: 'metadata'),
        writeMetadata: any(named: 'writeMetadata'),
        stamp: any(named: 'stamp'),
        onStage: any(named: 'onStage'),
      ),
    ).thenAnswer((_) async {
      await cubit.close();
      return fcSuccess(pageA);
    });

    await start(cubit);

    verify(() => repository.discard(pages: [pageA])).called(1);
    verifyNever(
      () => repository.process(
        rawB,
        maxBytes: 1000,
        metadata: any(named: 'metadata'),
        writeMetadata: any(named: 'writeMetadata'),
        stamp: any(named: 'stamp'),
        onStage: any(named: 'onStage'),
      ),
    );
    verifyNever(() => repository.clearCache());
  });
}
