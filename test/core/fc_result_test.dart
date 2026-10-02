import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FcResult', () {
    const failure = StorageFailure('disk full');

    test('success exposes its value and no failure', () {
      final result = fcSuccess(7);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 7);
      expect(result.failureOrNull, isNull);
    });

    test('failure exposes its failure and no value', () {
      final result = fcFailure<int>(failure);

      expect(result.isSuccess, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);
    });

    test('fold takes the failure branch first', () {
      expect(fcSuccess(2).fold((_) => -1, (v) => v * 2), 4);
      expect(fcFailure<int>(failure).fold((_) => -1, (v) => v * 2), -1);
    });

    test('when picks the matching branch, success-first', () {
      expect(fcSuccess(2).when(success: (v) => v * 2, failure: (_) => -1), 4);
      expect(
        fcFailure<int>(failure).when(success: (v) => v * 2, failure: (_) => -1),
        -1,
      );
    });

    test('map transforms success and passes failure through', () {
      expect(fcSuccess(3).map((v) => '$v').valueOrNull, '3');
      expect(fcFailure<int>(failure).map((v) => '$v').failureOrNull, failure);
    });

    test('flatMap chains successes', () {
      final result = fcSuccess(3).flatMap((v) => fcSuccess(v + 1));

      expect(result.valueOrNull, 4);
    });
  });

  group('FcResultFuture', () {
    const failure = StorageFailure('disk full');

    test('thenFlatMap chains fallible async steps', () async {
      final result = await Future.value(fcSuccess(2))
          .thenFlatMap((v) async => fcSuccess(v + 1))
          .thenFlatMap((v) async => fcSuccess(v * 10));

      expect(result.valueOrNull, 30);
    });

    test('thenFlatMap short-circuits on the first failure', () async {
      var secondStepRan = false;

      final result = await Future.value(fcSuccess(2))
          .thenFlatMap((_) async => fcFailure<int>(failure))
          .thenFlatMap((v) async {
            secondStepRan = true;
            return fcSuccess(v);
          });

      expect(result.failureOrNull, failure);
      expect(secondStepRan, isFalse, reason: 'must not run after a failure');
    });

    test('thenMap transforms an async success', () async {
      final result = await Future.value(fcSuccess(5)).thenMap((v) => '$v');

      expect(result.valueOrNull, '5');
    });
  });

  group('FcCameraFailure', () {
    test('compares by value', () {
      expect(
        const PermissionFailure(
          'denied',
          permission: 'camera',
          permanentlyDenied: true,
        ),
        const PermissionFailure(
          'denied',
          permission: 'camera',
          permanentlyDenied: true,
        ),
      );
    });

    test('differs when a discriminating field differs', () {
      expect(
        const SizeLimitFailure('too big', actualBytes: 10, limitBytes: 5),
        isNot(
          const SizeLimitFailure('too big', actualBytes: 11, limitBytes: 5),
        ),
      );
    });
  });
}
