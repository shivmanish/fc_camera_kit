import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';

import '../../../../../core/config/fc_cubit.dart';
import '../../../../../core/error/fc_camera_exception.dart';
import '../../../../../core/error/fc_camera_failure.dart';
import '../../../../../core/error/fc_exception_mapper.dart';
import '../../../../../core/utils/fc_result.dart';
import '../../../data/datasources/fc_live_camera.dart';
import '../../../data/datasources/fc_plugin_live_camera.dart';
import '../../../domain/entities/fc_camera_frame.dart';
import 'fc_camera_state.dart';

/// Live camera lifecycle; streams analysis frames only when `onFrame` is set.
class FcCameraCubit extends FcCubit<FcCameraState, XFile, FcCameraLens> {
  FcCameraCubit({
    void Function(FcCameraFrame frame)? onFrame,
    FcLiveCamera? camera,
    FcCameraLens lens = FcCameraLens.front,
    this.resolution = FcCameraResolution.analysis,
    this.useAnyLens = false,
    bool watchLifecycle = true,
  }) : _onFrame = onFrame,
       _framesWanted = onFrame != null,
       _lens = lens,
       _camera = camera ?? FcPluginLiveCamera(),
       super(initialState: const FcCameraStarting()) {
    if (watchLifecycle) {
      // Release when hidden, reopen on resume, or the preview goes black.
      _lifecycle = AppLifecycleListener(
        onInactive: _release,
        onResume: _reopen,
      );
    }
  }

  final FcCameraResolution resolution;

  /// Falls back to any available lens, e.g. on front-only tablets.
  final bool useAnyLens;
  final void Function(FcCameraFrame frame)? _onFrame;
  final FcLiveCamera _camera;
  AppLifecycleListener? _lifecycle;
  FcCameraLens _lens;

  /// A start abandons itself if this changes underneath it.
  int _generation = 0;
  bool _framesWanted;
  bool _capturing = false;
  bool _landscape = false;

  FcFlashMode _flash = FcFlashMode.auto;

  bool _flashMissing = false;

  double _zoom = 1;
  double _zoomAtPinchStart = 1;
  bool _zoomed = false;

  FcLiveCamera get camera => _camera;

  FcCameraLens get lens => _lens;

  bool get _flashAvailable => _lens == FcCameraLens.back && !_flashMissing;

  Future<void> start() async {
    if (isClosed) return;
    final generation = ++_generation;
    safeEmit(const FcCameraStarting());
    try {
      await _camera.open(lens: _lens, resolution: resolution);
      if (generation != _generation || isClosed) return;
      await _camera.lockOrientation(landscape: _landscape);
      final onFrame = _onFrame;
      if (_framesWanted && onFrame != null) await _camera.startFrames(onFrame);
      if (_flashAvailable) await _applyFlash();
      if (_zoomed) await _applyZoom();
      if (generation != _generation || isClosed) return;
      safeEmit(
        FcCameraReady(
          sensorAspect: _camera.sensorAspectRatio ?? 4 / 3,
          lens: _lens,
          canSwitchLens: _camera.lenses.length > 1,
          flash: _flashAvailable ? _flash : null,
        ),
      );
    } on FcCameraException catch (error) {
      if (generation != _generation) return;
      final lenses = _camera.lenses;
      if (useAnyLens && lenses.isNotEmpty && !lenses.contains(_lens)) {
        _lens = lenses.first;
        return start();
      }
      safeEmit(FcCameraError(error.toFailure(permission: 'camera')));
    } catch (error) {
      if (generation == _generation) {
        safeEmit(FcCameraError(UnknownFailure('Camera failed: $error')));
      }
    }
  }

  /// Frames stay stopped afterwards until [resumeFrames].
  Future<FcResult<XFile>> capture() async {
    final ready = state;
    if (_capturing || ready is! FcCameraReady) {
      return fcFailure(const CameraFailure('The camera is not ready.'));
    }
    _capturing = true;
    _framesWanted = false;
    safeEmit(ready.copyWith(capturing: true));
    try {
      return fcSuccess(await _camera.takePicture());
    } on FcCameraException catch (error) {
      return fcFailure(error.toFailure(permission: 'camera'));
    } catch (error) {
      return fcFailure(UnknownFailure('Capture failed: $error'));
    } finally {
      _capturing = false;
      _updateReady((ready) => ready.copyWith(capturing: false));
    }
  }

  Future<void> switchLens() async {
    final ready = state;
    if (ready is! FcCameraReady || !ready.canSwitchLens || ready.capturing) {
      return;
    }
    _lens = ready.lens == FcCameraLens.front
        ? FcCameraLens.back
        : FcCameraLens.front;
    await start();
  }

  /// A mode the camera refuses is skipped rather than blocking the user.
  Future<void> cycleFlash() async {
    final ready = state;
    if (ready is! FcCameraReady || ready.capturing) return;
    final current = ready.flash;
    if (current == null) return;
    final next = switch (current) {
      FcFlashMode.auto => FcFlashMode.on,
      FcFlashMode.on => FcFlashMode.off,
      FcFlashMode.off => FcFlashMode.auto,
    };
    final generation = _generation;
    try {
      await _camera.setFlash(next);
    } on FcCameraException {
      return;
    }
    _flash = next;
    if (generation != _generation) return;
    _updateReady((ready) => ready.copyWith(flash: () => next));
  }

  void beginZoom() => _zoomAtPinchStart = _zoom;

  Future<void> zoomBy(double scale) async {
    if (state is! FcCameraReady) return;
    final min = _camera.minZoom;
    final max = _camera.maxZoom;
    if (max <= min) return;
    final next = (_zoomAtPinchStart * scale).clamp(min, max).toDouble();
    // Skip invisible steps; pinches report every pixel.
    if ((next - _zoom).abs() < 0.01) return;
    _zoom = next;
    _zoomed = true;
    try {
      await _camera.setZoom(next);
    } on FcCameraException {
      // Keep the last level that worked.
    }
  }

  Future<void> syncOrientation({required bool landscape}) async {
    _landscape = landscape;
    // Not open yet: start() applies it.
    if (state is! FcCameraReady) return;
    try {
      await _camera.lockOrientation(landscape: landscape);
    } on FcCameraException catch (error) {
      safeEmit(FcCameraError(error.toFailure(permission: 'camera')));
    }
  }

  Future<void> pauseFrames() async {
    _framesWanted = false;
    if (state is! FcCameraReady) return;
    try {
      await _camera.stopFrames();
    } on FcCameraException {
      // The consumer drops stray frames anyway.
    }
  }

  Future<void> resumeFrames() async {
    final onFrame = _onFrame;
    if (onFrame == null) return;
    _framesWanted = true;
    if (state is! FcCameraReady) return;
    try {
      await _camera.startFrames(onFrame);
    } on FcCameraException catch (error) {
      safeEmit(FcCameraError(error.toFailure(permission: 'camera')));
    }
  }

  /// Re-applied per open so the UI and platform flash never disagree.
  Future<void> _applyFlash() async {
    try {
      await _camera.setFlash(_flash);
    } on FcCameraException {
      _flashMissing = true;
    }
  }

  Future<void> _applyZoom() async {
    final min = _camera.minZoom;
    final max = _camera.maxZoom;
    _zoom = max > min ? _zoom.clamp(min, max).toDouble() : min;
    try {
      await _camera.setZoom(_zoom);
    } on FcCameraException {
      _zoom = min;
    }
  }

  void _updateReady(FcCameraReady Function(FcCameraReady ready) change) {
    final current = state;
    if (current is FcCameraReady) safeEmit(change(current));
  }

  Future<void> _release() async {
    if (isClosed || state is FcCameraPaused || state is FcCameraError) return;
    _generation++;
    safeEmit(const FcCameraPaused());
    await _camera.close();
  }

  Future<void> _reopen() async {
    if (state is FcCameraPaused) await start();
  }

  @override
  Future<void> close() async {
    _generation++;
    _lifecycle?.dispose();
    _lifecycle = null;
    await _camera.close();
    return super.close();
  }
}
