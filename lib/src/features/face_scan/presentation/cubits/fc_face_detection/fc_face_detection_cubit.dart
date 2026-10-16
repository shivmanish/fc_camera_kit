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

/// Camera frames in, red or green out.
///
/// One frame is analysed at a time; frames arriving meanwhile are dropped,
/// so detection can never queue up behind the camera.
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

  /// The face that made the ring green; `null` unless ready.
  FcFaceObservation? get readyFace =>
      state is FcFaceDetectionReady ? _face : null;

  /// The last frame that passed every check, with its face; `null` unless
  /// ready. Becomes the photo, so the photo is exactly what was checked.
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

  /// Where the oval now is in the camera frame.
  void setTarget(FcFaceBox target) => _evaluate.target = target;

  /// Stops judging frames, e.g. while the taken photo is processed.
  void pause() => _paused = true;

  /// Starts again from scratch: a fresh blink is needed.
  void resume() {
    _paused = false;
    _evaluate.reset();
    _face = null;
    _readyFrame = null;
    safeEmit(const FcFaceDetectionSearching(FcFaceHint.noFace));
  }

  Future<void> _analyse(FcCameraFrame frame) async {
    try {
      // A detection that never answers must not freeze the ring on red.
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
      // A frame the detector couldn't read is skipped, not fatal.
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
