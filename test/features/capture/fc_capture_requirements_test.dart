import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('requirementsFor', () {
    test('gallery without location asks for nothing at all', () {
      expect(
        requirementsFor(FcCaptureSource.gallery, requireLocation: false),
        isEmpty,
        reason: 'the photo picker needs no permission',
      );
    });

    test('gallery with location asks only for location', () {
      expect(requirementsFor(FcCaptureSource.gallery, requireLocation: true), {
        FcPermissionType.location,
      });
    });

    test('camera without location asks only for camera', () {
      expect(requirementsFor(FcCaptureSource.camera, requireLocation: false), {
        FcPermissionType.camera,
      });
    });

    test('camera with location asks for both', () {
      expect(requirementsFor(FcCaptureSource.camera, requireLocation: true), {
        FcPermissionType.camera,
        FcPermissionType.location,
      });
    });

    test('gallery never asks for camera', () {
      for (final requireLocation in [true, false]) {
        expect(
          requirementsFor(
            FcCaptureSource.gallery,
            requireLocation: requireLocation,
          ),
          isNot(contains(FcPermissionType.camera)),
          reason: 'picking an existing photo cannot need the camera',
        );
      }
    });

    test('location is asked for only when configured', () {
      for (final source in FcCaptureSource.values) {
        expect(
          requirementsFor(source, requireLocation: false),
          isNot(contains(FcPermissionType.location)),
        );
      }
    });
  });

  group('capture() guard', () {
    setUp(FcCameraKit.reset);

    testWidgets('a throwing image source returns a failure, never throws', (
      tester,
    ) async {
      await FcCameraKit.instance.init();
      final source = _ThrowingSource();
      late FcResult<FcCaptureResult> result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await FcCameraKit.instance.capture(
                  context,
                  source: FcCaptureSource.gallery,
                  imageSource: source,
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // gallery + requireLocation:false asks for nothing, so the flow reaches
      // the picker directly and the throw must surface as a failure.
      expect(result.failureOrNull, isA<CameraFailure>());
    });

    testWidgets('a cancelled pick returns CancelledFailure', (tester) async {
      await FcCameraKit.instance.init();
      late FcResult<FcCaptureResult> result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await FcCameraKit.instance.capture(
                  context,
                  source: FcCaptureSource.gallery,
                  imageSource: _CancellingSource(),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(result.failureOrNull, isA<CancelledFailure>());
    });

    testWidgets('fails with ConfigurationFailure before init', (tester) async {
      late FcResult<FcCaptureResult> result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = fcFailure<FcCaptureResult>(
                const UnknownFailure('unset'),
              );
              return TextButton(
                onPressed: () async {
                  result = await FcCameraKit.instance.capture(context);
                },
                child: const Text('go'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(result.failureOrNull, isA<ConfigurationFailure>());
    });
  });
}

/// Fails the way a broken platform channel does.
class _ThrowingSource extends FcImageSource {
  @override
  Future<XFile?> pick(FcCaptureSource source) async {
    throw const CameraException('camera unavailable');
  }
}

/// Mimics the user backing out of the picker.
class _CancellingSource extends FcImageSource {
  @override
  Future<XFile?> pick(FcCaptureSource source) async => null;
}
