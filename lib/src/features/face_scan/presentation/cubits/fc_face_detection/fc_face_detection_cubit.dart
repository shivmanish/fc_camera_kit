import 'dart:async';

import '../../../../../core/config/fc_cubit.dart';
import '../../../../camera/domain/entities/fc_camera_frame.dart';
import '../../../data/datasources/fc_mlkit_face_detector.dart';
import '../../../domain/entities/fc_face_hint.dart';
import '../../../domain/entities/fc_face_observation.dart';
import '../../../domain/entities/fc_face_result.dart';
import '../../../domain/entities/fc_face_rules.dart';
import '../../../domain/repositories/fc_face_detector.dart';
import '../../../domain/usecases/fc_evaluate_face.dart';
import 'fc_face_detection_state.dart';

/// Judges one frame at a time; frames arriving meanwhile are dropped so none queue.
class FcFaceDetectionCubit
    extends FcCubit<FcFaceDetectionState, FcFaceCheck, FcCameraFrame> {
  FcFaceDetectionCubit({
    FcFaceDetector? detector,
    FcFaceRules rules = const FcFaceRules(),
    DateTime Function()? clock,
  }) : _detector = detector ?? FcMlKitFaceDetector(),
       _evaluate = FcEvaluateFace(rules: rules, clock: clock),
       super(initialState: const FcFaceDetectionSearching(FcFaceHint.noFace));

  static const _detectTimeout = Duration(seconds: 2);

  final FcFaceDetector _detector;
  final FcEvaluateFace _evaluate;
  bool _busy = false;
  bool _paused = false;
  FcFaceObservation? _face;
  FcCameraFrame? _readyFrame;

  FcFaceObservation? get readyFace =>
      state is FcFaceDetectionReady ? _face : null;

  /// Last fully passing frame; it becomes the photo, so the photo is what was checked.
  ({FcCameraFrame frame, FcFaceObservation face})? get readySnapshot {
    final frame = _readyFrame;
    final face = readyFace;
    return frame == null || face == null ? null : (frame: frame, face: face);
  }

  void onFrame(FcCameraFrame frame) {
    if (_busy || _paused || isClosed) return;
    _busy = true;
    unawaited(_analyse(frame));
  }

  void setTarget(FcFaceBox target) => _evaluate.target = target;

  void pause() => _paused = true;

  void resume() {
    _paused = false;
    _evaluate.reset();
    _face = null;
    _readyFrame = null;
    safeEmit(const FcFaceDetectionSearching(FcFaceHint.noFace));
  }

  Future<void> _analyse(FcCameraFrame frame) async {
    try {
      // A hung detection must not freeze the ring on red.
      final faces = await _detector.detect(frame).timeout(_detectTimeout);
      if (_paused || isClosed) return;

      final check = _evaluate(faces, luminance: frame.sampleLuminance());
      _face = check.face;
      _readyFrame = check.ready ? frame : null;
      safeEmit(
        check.ready
            ? const FcFaceDetectionReady()
            : FcFaceDetectionSearching(check.hint),
      );
    } catch (_) {
      // Unreadable frames are skipped, not fatal.
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> close() async {
    await _detector.close();
    return super.close();
  }
}
