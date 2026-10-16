import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../../../core/config/fc_camera_kit.dart';
import '../../../../../core/config/fc_cubit.dart';
import '../../../../../core/error/fc_camera_exception.dart';
import '../../../../../core/error/fc_camera_failure.dart';
import '../../../../../core/error/fc_exception_mapper.dart';
import '../../../../../core/image/fc_image_pipeline.dart';
import '../../../../../core/image/fc_image_store.dart';
import '../../../../../core/image/metadata/fc_geo_location.dart';
import '../../../../../core/image/metadata/fc_photo_metadata.dart';
import '../../../../../core/image/stamp/fc_stamp_style.dart';
import '../../../../../core/navigation/fc_flow_reporter.dart';
import '../../../../../core/permissions/fc_location_permission.dart';
import '../../../../../core/permissions/fc_permission_type.dart';
import '../../../../../core/utils/fc_result.dart';
import '../../../../camera/data/datasources/fc_frame_snapshot.dart';
import '../../../../camera/data/datasources/fc_live_camera.dart';
import '../../../../camera/domain/entities/fc_camera_frame.dart';
import '../../../../camera/domain/entities/fc_face_frame_geometry.dart';
import '../../../../camera/domain/entities/fc_face_frame_status.dart';
import '../../../../camera/presentation/cubits/fc_camera/fc_camera_cubit.dart';
import '../../../../camera/presentation/cubits/fc_camera/fc_camera_state.dart';
import '../../../domain/entities/fc_face_hint.dart';
import '../../../domain/entities/fc_face_observation.dart';
import '../../../domain/entities/fc_face_result.dart';
import '../../../domain/entities/fc_face_rules.dart';
import '../../../domain/repositories/fc_face_detector.dart';
import '../../../domain/repositories/fc_face_repository.dart';
import '../fc_face_detection/fc_face_detection_cubit.dart';
import '../fc_face_detection/fc_face_detection_state.dart';
import '../fc_face_session/fc_face_session_cubit.dart';
import '../fc_face_session/fc_face_session_state.dart';
import 'fc_face_scan_screen_state.dart';

/// Must not throw.
typedef FcLocationReader = Future<FcResult<FcGeoLocation?>> Function();

/// Drives the face scan screen; owns its child cubits and closes them with itself.
class FcFaceScanScreenCubit
    extends FcCubit<FcFaceScanScreenState, FcFaceResult, void> {
  FcFaceScanScreenCubit({
    required FcFlowReporter<FcFaceResult> reporter,
    this.blinks,
    this.maxBytes,
    this.embedMetadata,
    this.stamp,
    this.autoCaptureAfter,
    this.mirrorSelfie,
    this.placement,
    this.dateFormat,
    this.style = const FcStampStyle(),
    FcLiveCamera? camera,
    FcFaceDetector? detector,
    FcFaceRepository? repository,
    FcLocationReader? readLocation,
    FcFrameSaver? saveFrame,
  }) : _reporter = reporter,
       _saveFrame = saveFrame ?? _saveSnapshot,
       _liveCamera = camera,
       _detector = detector,
       _repository = repository,
       _readLocation = readLocation ?? _deviceLocation,
       super(initialState: const FcFaceScanPreparing());

  final int? blinks;
  final int? maxBytes;
  final bool? embedMetadata;
  final bool? stamp;
  final Duration? autoCaptureAfter;
  final bool? mirrorSelfie;
  final StampPlacement? placement;
  final String? dateFormat;
  final FcStampStyle style;

  final FcFlowReporter<FcFaceResult> _reporter;
  final FcLiveCamera? _liveCamera;
  final FcFaceDetector? _detector;
  final FcFaceRepository? _repository;
  final FcLocationReader _readLocation;
  final FcFrameSaver _saveFrame;

  FcCameraCubit? _camera;
  FcFaceDetectionCubit? _detection;
  FcFaceSessionCubit? _session;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _doneTimer;
  Timer? _autoCaptureTimer;

  /// Holds a hint briefly so red-to-red changes don't flicker.
  Timer? _hintHold;
  int _messageId = 0;

  bool _shooting = false;

  Size? _layout;

  late FcFaceRules _rules;
  late int _maxBytes;
  late Duration _autoCaptureAfter;
  late bool _mirror;
  late bool _writeMetadata;
  late bool _needsLocation;
  FcStampSpec? _stamp;
  Future<FcResult<FcGeoLocation?>>? _location;

  static const _showDoneFor = Duration(milliseconds: 450);
  static const _hintHoldFor = Duration(milliseconds: 400);

  static Future<XFile> _saveSnapshot(
    FcCameraFrame frame, {
    required bool mirror,
  }) => FcFrameSnapshot.save(frame, mirror: mirror);

  FcCameraCubit? get camera => _camera;

  Future<void> start() async {
    // Post-frame so the screen is listening and the sheet has a route.
    await SchedulerBinding.instance.endOfFrame;
    if (isClosed || state is! FcFaceScanPreparing) return;

    final failure = _configure();
    if (failure != null) return _leaveWithFailure(failure);

    safeEmit(
      FcFaceScanAskingPermission({
        FcPermissionType.camera,
        if (_needsLocation) FcPermissionType.location,
      }),
    );
  }

  Future<void> permissionResolved({required bool granted}) async {
    if (isClosed || state is! FcFaceScanAskingPermission) return;
    if (!granted) {
      return _leaveWithFailure(
        const PermissionFailure(
          'Camera or location access was not granted.',
          permission: 'camera',
          permanentlyDenied: false,
        ),
      );
    }

    _createChildren();
    _fetchLocation();
    _sync();
    await _camera?.start();
  }

  /// Re-aims the camera and rules on size change (rotation, split screen).
  void layoutChanged(Size size) {
    if (size.isEmpty || size == _layout || isClosed) return;
    _layout = size;
    unawaited(_camera?.syncOrientation(landscape: size.width > size.height));
    _updateTarget();
  }

  void _updateTarget() {
    final size = _layout;
    final camera = _camera?.state;
    if (size == null || camera is! FcCameraReady) return;

    final oval = FcFaceFrameGeometry.ovalInFrame(
      size,
      FcFaceFrameGeometry.uprightAspect(
        camera.sensorAspect,
        landscape: size.width > size.height,
      ),
    );
    _detection?.setTarget(
      FcFaceBox(
        left: oval.left,
        top: oval.top,
        width: oval.width,
        height: oval.height,
      ),
    );
  }

  /// Uses the last passing frame, so moving away afterwards can't spoil it.
  Future<void> shutter() async {
    final detection = _detection;
    final session = _session;
    if (detection == null || session == null) return;

    final snapshot = detection.readySnapshot;
    if (snapshot == null || session.isBusy || _shooting) return;

    _shooting = true;
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
    detection.pause();
    unawaited(_camera?.pauseFrames());

    final XFile photo;
    try {
      photo = await _saveFrame(snapshot.frame, mirror: _mirror);
    } catch (error) {
      _shooting = false;
      session.fail(
        error is FcCameraException
            ? error.toFailure()
            : UnknownFailure('Could not take the photo: $error'),
      );
      return;
    }
    _shooting = false;
    if (isClosed) {
      // Nothing will process it; delete the photo.
      await FcImageStore.deleteQuietly(photo.path);
      return;
    }

    await session.process(
      photo: photo,
      face: _mirror ? _mirrored(snapshot.face) : snapshot.face,
      maxBytes: _maxBytes,
      writeMetadata: _writeMetadata,
      resolveMetadata: _resolveMetadata,
      stamp: _stamp,
    );
  }

  /// Mirrors the face box for a flipped photo.
  static FcFaceObservation _mirrored(FcFaceObservation face) {
    final box = face.box;
    return FcFaceObservation(
      box: FcFaceBox(
        left: 1 - box.left - box.width,
        top: box.top,
        width: box.width,
        height: box.height,
      ),
      pose: FcHeadPose(
        yaw: -face.pose.yaw,
        pitch: face.pose.pitch,
        roll: -face.pose.roll,
      ),
      leftEyeOpen: face.rightEyeOpen,
      rightEyeOpen: face.leftEyeOpen,
      trackingId: face.trackingId,
    );
  }

  void action(FcFaceFrameAction action) {
    final session = _session;
    final failed = session?.state;
    if (failed is! FcFaceSessionFailed) return;

    switch (action) {
      case FcFaceFrameAction.primary:
        // Refetch a location that failed before.
        _fetchLocation();
        session!.reset();
        _detection?.resume();
        unawaited(_camera?.resumeFrames());
      case FcFaceFrameAction.secondary:
        _leaveWithFailure(failed.failure);
    }
  }

  /// Hands over a finished selfie instead of discarding it.
  void cancel() {
    final session = _session?.state;
    if (session is FcFaceSessionCompleted) return _complete(session.result);
    _reporter.cancelled();
    safeEmit(FcFaceScanLeaving(status: _currentStatus));
  }

  /// A system back that closed the route counts as a cancel.
  void systemBack({required bool didPop}) {
    if (didPop) _reporter.cancelled();
  }

  /// Route didn't close; [stillShown] when it's still visible.
  void routeNotClosed({required bool stillShown}) {
    if (!stillShown || isClosed) return;
    final leaving = state;
    safeEmit(
      FcFaceScanStranded(
        completed: leaving is FcFaceScanLeaving && leaving.result != null,
      ),
    );
  }

  FcCameraFailure? _configure() {
    final kit = FcCameraKit.instance;
    if (!kit.isInitialized) {
      return const ConfigurationFailure(
        'FcCameraKit.instance.init() must be called before scanFace().',
      );
    }

    final options = kit.faceScanOptions.copyWith(
      blinks: blinks,
      embedMetadata: embedMetadata,
      stamp: stamp,
      autoCaptureAfter: autoCaptureAfter,
      mirrorSelfie: mirrorSelfie,
    );
    if (options.blinks <= 0) {
      return const ConfigurationFailure('blinks must be positive.');
    }
    _maxBytes = maxBytes ?? kit.maxBytes;
    if (_maxBytes <= 0) {
      return const ConfigurationFailure('maxBytes must be positive.');
    }

    _autoCaptureAfter = options.autoCaptureAfter;
    _mirror = options.mirrorSelfie;
    _writeMetadata = options.embedMetadata;
    _stamp = options.stamp
        ? FcStampSpec(
            placement: placement ?? kit.placement,
            dateFormat: dateFormat ?? kit.dateFormat,
            includeDevice: kit.includeDeviceInStamp,
            style: style,
          )
        : null;
    _needsLocation = (_writeMetadata || options.stamp) && kit.requireLocation;
    _rules = FcFaceRules(blinks: options.blinks);
    return null;
  }

  void _createChildren() {
    final detection = _detection = FcFaceDetectionCubit(
      detector: _detector,
      rules: _rules,
    );
    final session = _session = FcFaceSessionCubit(repository: _repository);
    final camera = _camera = FcCameraCubit(
      onFrame: detection.onFrame,
      camera: _liveCamera,
    );
    final layout = _layout;
    if (layout != null) {
      unawaited(
        camera.syncOrientation(landscape: layout.width > layout.height),
      );
    }

    _subscriptions
      ..add(detection.stream.listen((_) => _sync()))
      ..add(session.stream.listen(_onSession))
      ..add(camera.stream.listen((_) => _updateTarget()));
  }

  /// Fetched while the user frames, so it's ready by capture.
  void _fetchLocation() {
    if (_needsLocation) _location = _readLocation();
  }

  static Future<FcResult<FcGeoLocation?>> _deviceLocation() async {
    try {
      final result = await FcLocationPermission.instance.getCurrentLocation(
        resolveAddress: true,
        requestIfNeeded: false,
      );
      return result.fold(fcFailure, fcSuccess);
    } catch (error) {
      return fcFailure(LocationFailure('Could not read the location: $error'));
    }
  }

  Future<FcResult<FcPhotoMetadata?>> _resolveMetadata() async {
    if (!_writeMetadata && _stamp == null) return fcSuccess(null);

    final kit = FcCameraKit.instance;
    final pending = _location;
    if (pending == null) return fcSuccess(kit.buildMetadata());

    final location = await pending;
    return location.fold(
      fcFailure<FcPhotoMetadata?>,
      (fix) => fcSuccess(kit.buildMetadata(location: fix)),
    );
  }

  void _onSession(FcFaceSessionState session) {
    _sync();
    if (session is! FcFaceSessionCompleted) return;

    // Let the tick show before the screen closes.
    _doneTimer?.cancel();
    _doneTimer = Timer(_showDoneFor, () => _complete(session.result));
  }

  void _complete(FcFaceResult result) {
    _doneTimer?.cancel();
    if (isClosed || state is FcFaceScanLeaving) return;
    _reporter.completed(result);
    safeEmit(FcFaceScanLeaving(result: result, status: _currentStatus));
  }

  void _leaveWithFailure(FcCameraFailure failure) {
    _reporter.failed(failure);
    safeEmit(FcFaceScanLeaving(status: _currentStatus));
  }

  FcFaceFrameStatus? get _currentStatus => switch (state) {
    FcFaceScanActive(:final status) => status,
    FcFaceScanLeaving(:final status) => status,
    _ => null,
  };

  void _sync() {
    final session = _session?.state;
    final detection = _detection?.state;
    if (isClosed || session == null || detection == null) return;
    if (state is FcFaceScanLeaving || state is FcFaceScanStranded) return;

    final status = _withMessageId(
      _statusFor(
        session,
        detection,
        countdown: _autoCaptureAfter > Duration.zero ? _autoCaptureAfter : null,
        frozenMirrored: _mirror,
      ),
    );
    _syncAutoCapture(status);
    safeEmit(
      FcFaceScanActive(
        status,
        // Back is allowed only when nothing is processing or awaiting hand-over.
        canPop: session is FcFaceSessionLive || session is FcFaceSessionFailed,
      ),
    );
  }

  /// Holds a red hint briefly before another red one; going green is never delayed.
  FcFaceFrameStatus _withMessageId(FcFaceFrameStatus next) {
    final current = switch (state) {
      FcFaceScanActive(:final status) => status,
      _ => null,
    };
    if (current == null || current.message != next.message) {
      final redToRed =
          current != null &&
          current.tone == FcFaceFrameTone.searching &&
          next.tone == FcFaceFrameTone.searching;
      if (redToRed && _hintHold != null) {
        return next.copyWith(
          message: current.message,
          messageId: current.messageId,
        );
      }
      _hintHold?.cancel();
      _hintHold = Timer(_hintHoldFor, () {
        _hintHold = null;
        _sync();
      });
      return next.copyWith(messageId: ++_messageId);
    }
    return next.copyWith(messageId: current.messageId);
  }

  /// Green for [_autoCaptureAfter] shoots; leaving green cancels.
  void _syncAutoCapture(FcFaceFrameStatus status) {
    final ready = status.tone == FcFaceFrameTone.ready;
    if (!ready || _autoCaptureAfter <= Duration.zero) {
      _autoCaptureTimer?.cancel();
      _autoCaptureTimer = null;
      return;
    }
    _autoCaptureTimer ??= Timer(_autoCaptureAfter, () {
      _autoCaptureTimer = null;
      unawaited(shutter());
    });
  }

  static FcFaceFrameStatus _statusFor(
    FcFaceSessionState session,
    FcFaceDetectionState detection, {
    required Duration? countdown,
    required bool frozenMirrored,
  }) => switch (session) {
    FcFaceSessionLive() => switch (detection) {
      FcFaceDetectionReady() => FcFaceFrameStatus(
        tone: FcFaceFrameTone.ready,
        message: countdown == null
            ? FcFaceHint.ready.message
            : 'Hold still, taking your photo',
        shutterEnabled: true,
        countdown: countdown,
      ),
      FcFaceDetectionSearching(:final hint) => FcFaceFrameStatus(
        tone: FcFaceFrameTone.searching,
        message: hint.message,
      ),
    },
    FcFaceSessionProcessing(:final photoPath, :final stages, :final stage) =>
      FcFaceFrameStatus(
        tone: FcFaceFrameTone.working,
        message: 'Preparing your photo',
        detail: 'Keep the app open',
        frozenImagePath: photoPath,
        frozenMirrored: frozenMirrored,
        steps: [for (final step in stages) step.label],
        currentStep: stage == null ? 0 : stages.indexOf(stage),
      ),
    FcFaceSessionCompleted(:final result) => FcFaceFrameStatus(
      tone: FcFaceFrameTone.done,
      message: 'Done',
      frozenImagePath: result.file.path,
      frozenMirrored: frozenMirrored,
    ),
    FcFaceSessionFailed(:final failure) => _failedStatus(failure),
  };

  static FcFaceFrameStatus _failedStatus(FcCameraFailure failure) {
    final (title, body) = switch (failure) {
      LocationFailure() || PermissionFailure(permission: 'location') => (
        "Couldn't get your location",
        'Move to an open area with signal and try again.',
      ),
      CameraFailure() => (
        "Couldn't take the photo",
        'Hold the phone steady and try again.',
      ),
      _ => ("Couldn't prepare your photo", 'Please try again.'),
    };
    return FcFaceFrameStatus(
      tone: FcFaceFrameTone.failed,
      message: title,
      detail: body,
      primaryAction: 'Try again',
      secondaryAction: 'Close',
    );
  }

  @override
  Future<void> close() async {
    // Report first so the host hears of the close immediately.
    _reporter.dispose();
    _doneTimer?.cancel();
    _autoCaptureTimer?.cancel();
    _hintHold?.cancel();
    // Close together so the camera starts releasing at once.
    await Future.wait([
      if (_camera case final camera?) camera.close(),
      if (_detection case final detection?) detection.close(),
      if (_session case final session?) session.close(),
      for (final subscription in _subscriptions) subscription.cancel(),
    ]);
    return super.close();
  }
}
