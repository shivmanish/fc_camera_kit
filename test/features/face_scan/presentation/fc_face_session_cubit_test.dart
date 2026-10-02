import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/entities/fc_face_capture.dart';
import 'package:fc_camera_kit/src/features/face_scan/domain/repositories/fc_face_repository.dart';
import 'package:fc_camera_kit/src/features/face_scan/presentation/cubits/fc_face_session/fc_face_session_cubit.dart';
import 'package:fc_camera_kit/src/features/face_scan/presentation/cubits/fc_face_session/fc_face_session_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fake_face_detector.dart';

class _MockRepository extends Mock implements FcFaceRepository {}

void main() {
  late _MockRepository repository;

  final photo = XFile('/raw/selfie.jpg');
  final face = framedFace();
  final capturedAt = DateTime(2026, 10, 2, 10);
  final metadata = FcPhotoMetadata(capturedAt: capturedAt, userName: 'Asha');
  final image = FcProcessedImage(
    file: XFile('/out/selfie.jpg'),
    sizeBytes: 900,
    width: 720,
    height: 960,
    wasCompressed: true,
    quality: 85,
    stamped: false,
  );
  const stamp = FcStampSpec(
    placement: StampPlacement.overlay,
    dateFormat: 'dd MMM yyyy',
  );

  setUpAll(() {
    registerFallbackValue(
      FcFaceCapture(file: photo, capturedAt: capturedAt, face: face),
    );
  });

  setUp(() {
    repository = _MockRepository();
    when(() => repository.discard(any())).thenAnswer((_) async {});
  });

  FcFaceSessionCubit build() =>
      FcFaceSessionCubit(repository: repository, clock: () => capturedAt);

  void processReturns(Future<FcResult<FcProcessedImage>> Function() answer) =>
      when(
        () => repository.process(
          any(),
          maxBytes: any(named: 'maxBytes'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((invocation) {
        final onStage =
            invocation.namedArguments[#onStage] as void Function(FcImageStage)?;
        onStage?.call(FcImageStage.compressing);
        return answer();
      });

  Future<void> process(
    FcFaceSessionCubit cubit, {
    FcStampSpec? stamp,
    FcResult<FcPhotoMetadata?>? resolved,
  }) => cubit.process(
    photo: photo,
    face: face,
    maxBytes: 1000,
    writeMetadata: true,
    stamp: stamp,
    resolveMetadata: () async => resolved ?? fcSuccess(metadata),
  );

  blocTest<FcFaceSessionCubit, FcFaceSessionState>(
    'processes the selfie step by step into a result',
    setUp: () => processReturns(() async => fcSuccess(image)),
    build: build,
    act: process,
    expect: () => [
      FcFaceSessionProcessing(
        photoPath: photo.path,
        stages: const [FcImageStage.compressing, FcImageStage.writingMetadata],
      ),
      FcFaceSessionProcessing(
        photoPath: photo.path,
        stages: const [FcImageStage.compressing, FcImageStage.writingMetadata],
        stage: FcImageStage.compressing,
      ),
      FcFaceSessionCompleted(
        FcFaceResult(
          file: image.file,
          width: 720,
          height: 960,
          sizeBytes: 900,
          capturedAt: capturedAt,
          livenessPassed: true,
          face: face.box,
          pose: face.pose,
          stamped: false,
          metadata: metadata,
        ),
      ),
    ],
  );

  blocTest<FcFaceSessionCubit, FcFaceSessionState>(
    'lists the stamp step first when stamping',
    setUp: () => processReturns(() async => fcSuccess(image)),
    build: build,
    act: (cubit) => process(cubit, stamp: stamp),
    verify: (cubit) {
      final captured = verify(
        () => repository.process(
          any(),
          maxBytes: 1000,
          writeMetadata: any(named: 'writeMetadata'),
          stamp: captureAny(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).captured;
      expect(captured.single, stamp);
    },
    expect: () => contains(
      FcFaceSessionProcessing(
        photoPath: photo.path,
        stages: const [
          FcImageStage.stamping,
          FcImageStage.compressing,
          FcImageStage.writingMetadata,
        ],
      ),
    ),
  );

  blocTest<FcFaceSessionCubit, FcFaceSessionState>(
    'a metadata failure ends in failure and deletes the photo',
    build: build,
    act: (cubit) =>
        process(cubit, resolved: fcFailure(const LocationFailure('no fix'))),
    expect: () => [
      isA<FcFaceSessionProcessing>(),
      const FcFaceSessionFailed(LocationFailure('no fix')),
    ],
    verify: (_) {
      verify(() => repository.discard(photo.path)).called(1);
      verifyNever(
        () => repository.process(
          any(),
          maxBytes: any(named: 'maxBytes'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      );
    },
  );

  blocTest<FcFaceSessionCubit, FcFaceSessionState>(
    'a processing failure ends in failure and deletes the photo',
    setUp: () => processReturns(
      () async => fcFailure(
        const SizeLimitFailure('too big', actualBytes: 2000, limitBytes: 1000),
      ),
    ),
    build: build,
    act: process,
    expect: () => [
      isA<FcFaceSessionProcessing>(),
      isA<FcFaceSessionProcessing>(),
      isA<FcFaceSessionFailed>(),
    ],
    verify: (_) => verify(() => repository.discard(photo.path)).called(1),
  );

  test('a second photo while busy is discarded, not processed', () async {
    final pending = Completer<FcResult<FcProcessedImage>>();
    processReturns(() => pending.future);
    final cubit = build();

    final first = process(cubit);
    await Future<void>.delayed(Duration.zero);
    await cubit.process(
      photo: XFile('/raw/second.jpg'),
      face: face,
      maxBytes: 1000,
      writeMetadata: true,
      resolveMetadata: () async => fcSuccess(metadata),
    );

    verify(() => repository.discard('/raw/second.jpg')).called(1);
    pending.complete(fcSuccess(image));
    await first;
    expect(cubit.state, isA<FcFaceSessionCompleted>());
    await cubit.close();
  });

  test('a result produced after close is deleted', () async {
    final pending = Completer<FcResult<FcProcessedImage>>();
    processReturns(() => pending.future);
    final cubit = build();

    final running = process(cubit);
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    pending.complete(fcSuccess(image));
    await running;

    verify(() => repository.discard(image.file.path)).called(1);
  });

  blocTest<FcFaceSessionCubit, FcFaceSessionState>(
    'reset goes back to waiting for the shutter',
    build: build,
    seed: () => const FcFaceSessionFailed(CameraFailure('x')),
    act: (cubit) => cubit.reset(),
    expect: () => [const FcFaceSessionLive()],
  );
}
