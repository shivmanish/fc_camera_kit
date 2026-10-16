import 'package:fc_camera_kit/fc_camera_kit.dart';

import 'home_state.dart';

/// Drives the demo screen.
/// Context-free: the page runs the permission gate, then [refreshAccess].
class HomeCubit extends FcCubit<HomeState, void, void> {
  HomeCubit() : super(initialState: const HomeState());

  FcCameraKit get _kit => FcCameraKit.instance;

  Future<void> load() async {
    safeEmit(
      state.copyWith(
        user: _kit.user,
        placement: _kit.placement,
        stampScans: _kit.scanOptions.stamp,
      ),
    );
    await refreshAccess();
    _syncMetadata();
  }

  Future<void> refreshAccess() async {
    safeEmit(state.copyWith(checkingAccess: true));
    try {
      final statuses = await FcPermissions.instance.statusOfAll(
        FcPermissions.captureDefaults,
      );
      final enabled = await FcPermissions.instance.isLocationServiceEnabled();

      safeEmit(state.copyWith(statuses: statuses, serviceEnabled: enabled));
    } finally {
      safeEmit(state.copyWith(checkingAccess: false));
    }
  }

  Future<void> fetchLocation() async {
    safeEmit(state.copyWith(locating: true, clearLocationError: true));

    final result = await FcLocationPermission.instance.getCurrentLocation(
      resolveAddress: true,
    );

    result.when(
      success: (location) => safeEmit(state.copyWith(location: location)),
      failure: (failure) => safeEmit(state.copyWith(locationError: failure)),
    );

    safeEmit(state.copyWith(locating: false));
    _syncMetadata();
    await refreshAccess();
  }

  void setUser(FcUser user) {
    _kit.setUser(user);
    safeEmit(state.copyWith(user: user));
    _syncMetadata();
  }

  void clearUser() {
    _kit.clearUser();
    safeEmit(state.copyWith(clearUser: true));
    _syncMetadata();
  }

  void dismissLocationError() =>
      safeEmit(state.copyWith(clearLocationError: true));

  void captureStarted() =>
      safeEmit(state.copyWith(capturing: true, clearCaptureError: true));

  /// A cancelled capture is not treated as an error.
  void captureFinished(FcResult<FcCaptureResult> result) {
    result.when(
      // Newest first.
      success: (capture) =>
          safeEmit(state.copyWith(captures: [capture, ...state.captures])),
      failure: (failure) => safeEmit(
        failure is CancelledFailure
            ? state
            : state.copyWith(captureError: failure),
      ),
    );

    safeEmit(state.copyWith(capturing: false));
    _syncMetadata();
  }

  void scanFinished(FcResult<FcScanResult> result) {
    result.when(
      success: (scan) =>
          safeEmit(state.copyWith(scans: [...scan.pages, ...state.scans])),
      failure: (failure) => safeEmit(
        failure is CancelledFailure
            ? state
            : state.copyWith(captureError: failure),
      ),
    );

    safeEmit(state.copyWith(capturing: false));
  }

  void faceScanFinished(FcResult<FcFaceResult> result) {
    result.when(
      success: (face) =>
          safeEmit(state.copyWith(faces: [face, ...state.faces])),
      failure: (failure) => safeEmit(
        failure is CancelledFailure
            ? state
            : state.copyWith(captureError: failure),
      ),
    );

    safeEmit(state.copyWith(capturing: false));
  }

  void dismissCaptureError() =>
      safeEmit(state.copyWith(clearCaptureError: true));

  void setPlacement(StampPlacement placement) {
    _kit.setPlacement(placement);
    safeEmit(state.copyWith(placement: placement));
  }

  void setStampScans(bool stamp) => safeEmit(state.copyWith(stampScans: stamp));

  void _syncMetadata() => safeEmit(
    state.copyWith(metadata: _kit.buildMetadata(location: state.location)),
  );
}
