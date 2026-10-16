import 'dart:io';

import 'package:camera/camera.dart' as cam;
import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/error/fc_camera_exception.dart';
import '../../domain/entities/fc_camera_frame.dart';
import 'fc_frame_rotation.dart';
import 'fc_live_camera.dart';

final class FcPluginLiveCamera implements FcLiveCamera {
  cam.CameraController? _controller;
  FcCameraLens _lens = FcCameraLens.front;
  Set<FcCameraLens> _lenses = const {};
  double _minZoom = 1;
  double _maxZoom = 1;
  bool _closed = false;

  /// Some devices fail to open while the old controller is still releasing.
  Future<void>? _disposing;

  /// Only the latest open keeps its controller.
  int _token = 0;

  @override
  FcCameraLens get lens => _lens;

  @override
  Set<FcCameraLens> get lenses => _lenses;

  @override
  double get minZoom => _minZoom;

  @override
  double get maxZoom => _maxZoom;

  @override
  double? get sensorAspectRatio {
    final value = _controller?.value;
    if (value == null || !value.isInitialized || value.previewSize == null) {
      return null;
    }
    return value.aspectRatio;
  }

  @override
  Future<void> lockOrientation({required bool landscape}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final device = controller.value.deviceOrientation;
    final target = !landscape
        ? DeviceOrientation.portraitUp
        : device == DeviceOrientation.landscapeRight
        ? DeviceOrientation.landscapeRight
        : DeviceOrientation.landscapeLeft;
    if (controller.value.lockedCaptureOrientation == target) return;
    await _guard(
      'lock the camera orientation',
      () => controller.lockCaptureOrientation(target),
    );
  }

  @override
  Future<void> open({
    FcCameraLens lens = FcCameraLens.front,
    FcCameraResolution resolution = FcCameraResolution.analysis,
  }) async {
    final token = ++_token;
    _closed = false;
    _lens = lens;
    await _disposeController();

    final controller = await _guard('open the camera', () async {
      final cameras = await cam.availableCameras();
      _lenses = {
        for (final camera in cameras)
          if (camera.lensDirection == cam.CameraLensDirection.front)
            FcCameraLens.front
          else if (camera.lensDirection == cam.CameraLensDirection.back)
            FcCameraLens.back,
      };
      final wanted = lens == FcCameraLens.front
          ? cam.CameraLensDirection.front
          : cam.CameraLensDirection.back;
      final description = cameras
          .where((camera) => camera.lensDirection == wanted)
          .firstOrNull;
      if (description == null) {
        throw const CameraException('This device has no camera on that side.');
      }

      final controller = cam.CameraController(
        description,
        switch (resolution) {
          FcCameraResolution.analysis => cam.ResolutionPreset.high,
          FcCameraResolution.photo => cam.ResolutionPreset.veryHigh,
        },
        enableAudio: false,
        // Formats ML Kit reads without per-frame conversion.
        imageFormatGroup: Platform.isIOS
            ? cam.ImageFormatGroup.bgra8888
            : cam.ImageFormatGroup.nv21,
      );
      try {
        await controller.initialize();
      } catch (_) {
        await controller.dispose();
        rethrow;
      }
      return controller;
    });

    // Closed or superseded mid-open: release now, don't leak it.
    if (_closed || token != _token) {
      await controller.dispose();
      return;
    }
    _controller = controller;
    final (min, max) = await _zoomRange(controller);
    _minZoom = min;
    _maxZoom = max;
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return cam.CameraPreview(controller);
  }

  @override
  Future<void> startFrames(void Function(FcCameraFrame frame) onFrame) async {
    final controller = _controller;
    if (controller == null || controller.value.isStreamingImages) return;

    await _guard('start the camera stream', () {
      return controller.startImageStream((image) {
        final frame = _toFrame(controller, image);
        if (frame != null) onFrame(frame);
      });
    });
  }

  @override
  Future<void> stopFrames() async {
    final controller = _controller;
    if (controller == null || !controller.value.isStreamingImages) return;
    await _guard('stop the camera stream', controller.stopImageStream);
  }

  @override
  Future<void> setFlash(FcFlashMode mode) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CameraException('The camera is not open.');
    }
    await _guard(
      'set the flash',
      () => controller.setFlashMode(switch (mode) {
        FcFlashMode.auto => cam.FlashMode.auto,
        FcFlashMode.on => cam.FlashMode.always,
        FcFlashMode.off => cam.FlashMode.off,
      }),
    );
  }

  @override
  Future<void> setZoom(double level) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await _guard('zoom', () => controller.setZoomLevel(level));
  }

  @override
  Future<XFile> takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CameraException('The camera is not open.');
    }
    // Some Android devices fail to capture while analysis is running.
    await stopFrames();
    return _guard('take the photo', controller.takePicture);
  }

  @override
  Future<void> close() async {
    _token++;
    _closed = true;
    await _disposeController();
  }

  Future<void> _disposeController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) _disposing = _release(controller);
    return _disposing ?? Future<void>.value();
  }

  static Future<void> _release(cam.CameraController controller) async {
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // dispose() below releases the stream anyway.
    }
    try {
      await controller.dispose();
    } catch (_) {
      // Already released by the platform.
    }
  }

  static Future<(double, double)> _zoomRange(
    cam.CameraController controller,
  ) async {
    try {
      return await (
        controller.getMinZoomLevel(),
        controller.getMaxZoomLevel(),
      ).wait;
    } catch (_) {
      return (1.0, 1.0);
    }
  }

  FcCameraFrame? _toFrame(
    cam.CameraController controller,
    cam.CameraImage image,
  ) {
    final format = switch (image.format.group) {
      cam.ImageFormatGroup.nv21 => FcFrameFormat.nv21,
      cam.ImageFormatGroup.bgra8888 => FcFrameFormat.bgra8888,
      _ => null,
    };
    // ML Kit needs a single-plane nv21 or bgra8888 frame.
    if (format == null || image.planes.length != 1) return null;

    final plane = image.planes.first;
    return FcCameraFrame(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      format: format,
      rotationDegrees: fcFrameRotation(
        isIOS: Platform.isIOS,
        sensorOrientation: controller.description.sensorOrientation,
        // Preview and photo follow the locked orientation.
        deviceRotation: _degrees(
          controller.value.lockedCaptureOrientation ??
              controller.value.deviceOrientation,
        ),
        lens: _lens,
      ),
    );
  }

  static int _degrees(DeviceOrientation orientation) => switch (orientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };

  static Future<T> _guard<T>(String action, Future<T> Function() run) async {
    try {
      return await run();
    } on FcCameraException {
      rethrow;
    } on cam.CameraException catch (error, stackTrace) {
      switch (error.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
        case 'CameraAccessRestricted':
          throw PermissionException(
            'Camera access was not granted.',
            permanentlyDenied: error.code != 'CameraAccessDenied',
            cause: error,
            stackTrace: stackTrace,
          );
        default:
          throw CameraException(
            'Could not $action: ${error.description ?? error.code}',
            cause: error,
            stackTrace: stackTrace,
          );
      }
    } catch (error, stackTrace) {
      throw CameraException(
        'Could not $action.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
