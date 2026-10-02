import 'package:bloc_test/bloc_test.dart';
import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSource extends Mock implements FcImageSource {}

void main() {
  late _MockSource source;

  setUpAll(() => registerFallbackValue(FcCaptureSource.camera));
  setUp(() => source = _MockSource());

  FcCaptureCubit build() => FcCaptureCubit(source: source);

  group('fromCamera', () {
    blocTest<FcCaptureCubit, FcCaptureState>(
      'emits picking then picked',
      setUp: () => when(() => source.pick(any())).thenAnswer((_) async {
        return XFile('/tmp/shot.jpg');
      }),
      build: build,
      act: (cubit) => cubit.fromCamera(),
      expect: () => [
        const FcCapturePicking(FcCaptureSource.camera),
        FcCapturePicked(XFile('/tmp/shot.jpg')),
      ],
      verify: (_) =>
          verify(() => source.pick(FcCaptureSource.camera)).called(1),
    );

    blocTest<FcCaptureCubit, FcCaptureState>(
      'a cancelled pick ends the picking state, it does not hang',
      setUp: () => when(() => source.pick(any())).thenAnswer((_) async => null),
      build: build,
      act: (cubit) => cubit.fromCamera(),
      verify: (cubit) {
        expect(cubit.state, isA<FcCaptureFailed>());
        expect(
          (cubit.state as FcCaptureFailed).failure,
          isA<CancelledFailure>(),
          reason: 'backing out is not a real error',
        );
      },
    );

    blocTest<FcCaptureCubit, FcCaptureState>(
      'a platform error becomes a CameraFailure, never an escaped exception',
      setUp: () => when(
        () => source.pick(any()),
      ).thenThrow(const CameraException('camera busy')),
      build: build,
      act: (cubit) => cubit.fromCamera(),
      verify: (cubit) {
        expect(cubit.state, isA<FcCaptureFailed>());
        expect((cubit.state as FcCaptureFailed).failure, isA<CameraFailure>());
      },
    );

    blocTest<FcCaptureCubit, FcCaptureState>(
      'an unexpected throw is still contained',
      setUp: () => when(() => source.pick(any())).thenThrow(StateError('boom')),
      build: build,
      act: (cubit) => cubit.fromCamera(),
      verify: (cubit) => expect(
        (cubit.state as FcCaptureFailed).failure,
        isA<UnknownFailure>(),
      ),
    );
  });

  group('fromGallery', () {
    blocTest<FcCaptureCubit, FcCaptureState>(
      'asks the source for the gallery',
      setUp: () => when(() => source.pick(any())).thenAnswer((_) async {
        return XFile('/tmp/pick.jpg');
      }),
      build: build,
      act: (cubit) => cubit.fromGallery(),
      verify: (_) =>
          verify(() => source.pick(FcCaptureSource.gallery)).called(1),
    );
  });

  group('reset', () {
    blocTest<FcCaptureCubit, FcCaptureState>(
      'returns to idle so a second capture starts clean',
      setUp: () => when(() => source.pick(any())).thenAnswer((_) async {
        return XFile('/tmp/shot.jpg');
      }),
      build: build,
      act: (cubit) async {
        await cubit.fromCamera();
        cubit.reset();
      },
      verify: (cubit) => expect(cubit.state, isA<FcCaptureIdle>()),
    );
  });

  group('FcStampStage', () {
    test('every stage has user-facing copy', () {
      for (final stage in FcStampStage.values) {
        expect(stage.label, isNotEmpty);
      }
    });
  });
}
