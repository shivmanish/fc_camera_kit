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

/// Owns the live camera: opening, frames, one photo, and the app lifecycle.
class FcCameraCubit extends FcCubit<FcCameraState, XFile, FcCameraLens> {
  FcCameraCubit({
    required void Function(FcCameraFrame frame) onFrame,
    FcLiveCamera? camera,
    this.lens = FcCameraLens.front,
    bool watchLifecycle = true,
  }) : _onFrame = onFrame,
       _camera = camera ?? FcPluginLiveCamera(),
       super(initialState: const FcCameraStarting()) {
    if (watchLifecycle) {
      // The plugin leaves lifecycle to the app: release when hidden, reopen
      // when back, or the preview goes black after a call or app switch.
      _lifecycle = AppLifecycleListener(
        onInactive: _release,
        onResume: _reopen,
      );
    }
  }

  final FcCameraLens lens;
  final void Function(FcCameraFrame frame) _onFrame;
  final FcLiveCamera _camera;
  AppLifecycleListener? _lifecycle;

  /// Bumped on every release; a start that sees it change abandons itself.
  int _generation = 0;
  bool _framesWanted = true;
  bool _capturing = false;
  bool _landscape = false;

  FcLiveCamera get camera => _camera;

  Future<void> start() async {
    if (isClosed) return;
    final generation = ++_generation;
    safeEmit(const FcCameraStarting());
    try {
      await _camera.open(lens: lens);
      if (generation != _generation || isClosed) return;
      await _camera.lockOrientation(landscape: _landscape);
      if (_framesWanted) await _camera.startFrames(_onFrame);
      if (generation != _generation || isClosed) return;
      safeEmit(FcCameraReady(sensorAspect: _camera.sensorAspectRatio ?? 4 / 3));
    } on FcCameraException catch (error) {
      if (generation == _generation) {
        safeEmit(FcCameraError(error.toFailure(permission: 'camera')));
      }
    } catch (error) {
      if (generation == _generation) {
        safeEmit(FcCameraError(UnknownFailure('Camera failed: $error')));
      }
    }
  }

  /// Takes one photo. Frames stay stopped afterwards until [resumeFrames].
  Future<FcResult<XFile>> capture() async {
    if (_capturing || state is! FcCameraReady) {
      return fcFailure(const CameraFailure('The camera is not ready.'));
    }
    _capturing = true;
    _framesWanted = false;
    try {
      return fcSuccess(await _camera.takePicture());
    } on FcCameraException catch (error) {
      return fcFailure(error.toFailure(permission: 'camera'));
    } catch (error) {
      return fcFailure(UnknownFailure('Capture failed: $error'));
    } finally {
      _capturing = false;
    }
  }

  /// Follows the screen: the preview, photo and frames match its orientation.
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

  /// Stops analysis frames (the preview keeps running) until [resumeFrames].
  Future<void> pauseFrames() async {
    _framesWanted = false;
    if (state is! FcCameraReady) return;
    try {
      await _camera.stopFrames();
    } on FcCameraException {
      // Frames that keep coming are dropped by the consumer anyway.
    }
  }

  Future<void> resumeFrames() async {
    _framesWanted = true;
    if (state is! FcCameraReady) return;
    try {
      await _camera.startFrames(_onFrame);
    } on FcCameraException catch (error) {
      safeEmit(FcCameraError(error.toFailure(permission: 'camera')));
    }
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
