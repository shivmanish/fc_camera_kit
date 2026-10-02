import 'package:bloc_test/bloc_test.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermissions extends Mock implements FcPermissions {}

const _required = {FcPermissionType.camera, FcPermissionType.location};

void main() {
  late _MockPermissions permissions;

  setUp(() {
    permissions = _MockPermissions();
    when(() => permissions.isLocationServiceEnabled()).thenAnswer((_) async {
      return true;
    });
    when(() => permissions.openAppSettings()).thenAnswer((_) async => true);
    when(() => permissions.openLocationSettings()).thenAnswer((_) async {
      return true;
    });
  });

  void stubStatuses(Map<FcPermissionType, FcPermissionStatus> statuses) {
    when(() => permissions.statusOfAll(any())).thenAnswer((_) async {
      return statuses;
    });
  }

  FcPermissionCubit build() => FcPermissionCubit(
    required: _required,
    permissions: permissions,
    watchLifecycle: false,
  );

  group('refresh', () {
    blocTest<FcPermissionCubit, FcPermissionState>(
      'loads statuses and marks everything granted',
      setUp: () => stubStatuses({
        FcPermissionType.camera: FcPermissionStatus.granted,
        FcPermissionType.location: FcPermissionStatus.granted,
      }),
      build: build,
      verify: (cubit) {
        expect(cubit.state.loaded, isTrue);
        expect(cubit.state.allGranted, isTrue);
        expect(cubit.state.needsAppSettings, isFalse);
      },
    );

    blocTest<FcPermissionCubit, FcPermissionState>(
      'a single denial blocks the gate',
      setUp: () => stubStatuses({
        FcPermissionType.camera: FcPermissionStatus.granted,
        FcPermissionType.location: FcPermissionStatus.denied,
      }),
      build: build,
      verify: (cubit) => expect(cubit.state.allGranted, isFalse),
    );

    blocTest<FcPermissionCubit, FcPermissionState>(
      'flags App Settings only for a permanent denial',
      setUp: () => stubStatuses({
        FcPermissionType.camera: FcPermissionStatus.deniedForever,
        FcPermissionType.location: FcPermissionStatus.granted,
      }),
      build: build,
      verify: (cubit) => expect(cubit.state.needsAppSettings, isTrue),
    );

    blocTest<FcPermissionCubit, FcPermissionState>(
      'a plain denial does not route to App Settings',
      setUp: () => stubStatuses({
        FcPermissionType.camera: FcPermissionStatus.denied,
        FcPermissionType.location: FcPermissionStatus.denied,
      }),
      build: build,
      verify: (cubit) => expect(cubit.state.needsAppSettings, isFalse),
    );

    blocTest<FcPermissionCubit, FcPermissionState>(
      'reads the location service toggle when location is required',
      setUp: () {
        stubStatuses({
          FcPermissionType.camera: FcPermissionStatus.granted,
          FcPermissionType.location: FcPermissionStatus.granted,
        });
        when(() => permissions.isLocationServiceEnabled()).thenAnswer((
          _,
        ) async {
          return false;
        });
      },
      build: build,
      verify: (cubit) => expect(cubit.state.serviceEnabled, isFalse),
    );

    blocTest<FcPermissionCubit, FcPermissionState>(
      'skips the service check when location is not required',
      setUp: () =>
          stubStatuses({FcPermissionType.camera: FcPermissionStatus.granted}),
      build: () => FcPermissionCubit(
        required: const {FcPermissionType.camera},
        permissions: permissions,
        watchLifecycle: false,
      ),
      verify: (_) => verifyNever(() => permissions.isLocationServiceEnabled()),
    );
  });

  group('service versus permission', () {
    blocTest<FcPermissionCubit, FcPermissionState>(
      'granted permission with the service off is still granted',
      setUp: () {
        stubStatuses({
          FcPermissionType.camera: FcPermissionStatus.granted,
          FcPermissionType.location: FcPermissionStatus.granted,
        });
        when(() => permissions.isLocationServiceEnabled()).thenAnswer((
          _,
        ) async {
          return false;
        });
      },
      build: build,
      verify: (cubit) {
        // The permission sheet must not appear for a disabled service — it
        // cannot turn GPS on. Only the location dialog can.
        expect(cubit.state.allGranted, isTrue);
        expect(cubit.state.serviceEnabled, isFalse);
      },
    );

    blocTest<FcPermissionCubit, FcPermissionState>(
      'a denied permission still blocks, service on or not',
      setUp: () {
        stubStatuses({
          FcPermissionType.camera: FcPermissionStatus.granted,
          FcPermissionType.location: FcPermissionStatus.denied,
        });
        when(() => permissions.isLocationServiceEnabled()).thenAnswer((
          _,
        ) async {
          return true;
        });
      },
      build: build,
      verify: (cubit) => expect(cubit.state.allGranted, isFalse),
    );
  });

  group('requestAll', () {
    blocTest<FcPermissionCubit, FcPermissionState>(
      'requests, then re-reads and clears busy',
      setUp: () {
        stubStatuses({
          FcPermissionType.camera: FcPermissionStatus.denied,
          FcPermissionType.location: FcPermissionStatus.denied,
        });
        when(() => permissions.requestAll(any())).thenAnswer((_) async {
          stubStatuses({
            FcPermissionType.camera: FcPermissionStatus.granted,
            FcPermissionType.location: FcPermissionStatus.granted,
          });
          return {};
        });
      },
      build: build,
      act: (cubit) => cubit.requestAll(),
      verify: (cubit) {
        expect(cubit.state.allGranted, isTrue);
        expect(cubit.state.busy, isFalse);
        verify(() => permissions.requestAll(_required)).called(1);
      },
    );
  });

  group('settings hand-off', () {
    blocTest<FcPermissionCubit, FcPermissionState>(
      'openAppSettings delegates and clears busy',
      setUp: () => stubStatuses({
        FcPermissionType.camera: FcPermissionStatus.deniedForever,
      }),
      build: build,
      act: (cubit) => cubit.openAppSettings(),
      verify: (cubit) {
        verify(() => permissions.openAppSettings()).called(1);
        expect(cubit.state.busy, isFalse);
      },
    );

    blocTest<FcPermissionCubit, FcPermissionState>(
      'openLocationSettings delegates and clears busy',
      setUp: () =>
          stubStatuses({FcPermissionType.location: FcPermissionStatus.granted}),
      build: build,
      act: (cubit) => cubit.openLocationSettings(),
      verify: (cubit) {
        verify(() => permissions.openLocationSettings()).called(1);
        expect(cubit.state.busy, isFalse);
      },
    );
  });

  group('resilience', () {
    blocTest<FcPermissionCubit, FcPermissionState>(
      'a throwing status read still marks the state loaded, never rethrows',
      setUp: () {
        when(
          () => permissions.statusOfAll(any()),
        ).thenThrow(Exception('platform channel unavailable'));
      },
      build: build,
      verify: (cubit) {
        expect(cubit.state.loaded, isTrue);
        expect(cubit.state.allGranted, isFalse);
      },
    );

    blocTest<FcPermissionCubit, FcPermissionState>(
      'busy clears even when requesting blows up',
      setUp: () {
        stubStatuses({FcPermissionType.camera: FcPermissionStatus.denied});
        when(() => permissions.requestAll(any())).thenThrow(Exception('boom'));
      },
      build: build,
      act: (cubit) async {
        try {
          await cubit.requestAll();
        } catch (_) {
          // surfaced to the caller; the state must still be usable
        }
      },
      verify: (cubit) => expect(cubit.state.busy, isFalse),
    );

    blocTest<FcPermissionCubit, FcPermissionState>(
      'busy clears even when the settings hand-off blows up',
      setUp: () {
        stubStatuses({FcPermissionType.camera: FcPermissionStatus.denied});
        when(() => permissions.openAppSettings()).thenThrow(Exception('boom'));
      },
      build: build,
      act: (cubit) async {
        try {
          await cubit.openAppSettings();
        } catch (_) {}
      },
      verify: (cubit) => expect(cubit.state.busy, isFalse),
    );
  });

  group('FcPermissionState', () {
    test('is not granted until the first read lands', () {
      const state = FcPermissionState(required: _required);

      expect(state.loaded, isFalse);
      expect(state.allGranted, isFalse);
    });

    test('loaded with no statuses is NOT granted', () {
      // `[].every(...)` is vacuously true — this pins the gate shut when a
      // status read fails and leaves the map empty.
      const state = FcPermissionState(required: _required, loaded: true);

      expect(state.allGranted, isFalse);
    });

    test('partial coverage is not granted', () {
      const state = FcPermissionState(
        required: _required,
        statuses: {FcPermissionType.camera: FcPermissionStatus.granted},
        loaded: true,
      );

      expect(state.allGranted, isFalse);
    });

    test('requiring nothing is trivially granted', () {
      const state = FcPermissionState(loaded: true);

      expect(state.allGranted, isTrue);
    });

    test('copyWith preserves every field it was not given', () {
      const original = FcPermissionState(
        required: _required,
        statuses: {FcPermissionType.camera: FcPermissionStatus.granted},
        serviceEnabled: false,
        busy: true,
        loaded: true,
      );

      final copy = original.copyWith(busy: false);

      expect(copy.required, original.required);
      expect(copy.statuses, original.statuses);
      expect(copy.serviceEnabled, original.serviceEnabled);
      expect(copy.loaded, original.loaded);
      expect(copy.busy, isFalse);
    });

    test('orders rows by declaration, not by map insertion', () {
      const state = FcPermissionState(
        required: _required,
        statuses: {
          FcPermissionType.location: FcPermissionStatus.denied,
          FcPermissionType.camera: FcPermissionStatus.denied,
        },
        loaded: true,
      );

      expect(state.ordered, [
        FcPermissionType.camera,
        FcPermissionType.location,
      ]);
    });
  });
}
