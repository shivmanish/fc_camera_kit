import 'package:fc_camera_kit/fc_camera_kit.dart';

import 'home_state.dart';

/// Drives the demo screen.
///
/// Deliberately holds no `BuildContext`: `FcPermissionGate.ensure` needs one,
/// so the widget runs the gate and calls [refreshAccess] afterwards.
class HomeCubit extends FcCubit<HomeState, void, void> {
  HomeCubit() : super(initialState: const HomeState());

  FcCameraKit get _kit => FcCameraKit.instance;

  /// Reads the user seeded in `main()` plus the current access state.
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

  /// Re-reads permission statuses and the device location toggle.
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

  /// Records whatever `FcCameraKit.capture` handed back.
  ///
  /// A cancellation is not surfaced as an error — the user chose it.
  void captureFinished(FcResult<FcCaptureResult> result) {
    result.when(
      // Newest first, so the most recent shot is where the eye lands.
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

  /// Records whatever `FcCameraKit.scan` handed back.
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

  void dismissCaptureError() =>
      safeEmit(state.copyWith(clearCaptureError: true));

  /// Applies to the kit, so the next capture picks it up with no other wiring.
  void setPlacement(StampPlacement placement) {
    _kit.setPlacement(placement);
    safeEmit(state.copyWith(placement: placement));
  }

  void setStampScans(bool stamp) => safeEmit(state.copyWith(stampScans: stamp));

  /// Rebuilds the preview so it always reflects the current user and fix.
  void _syncMetadata() => safeEmit(
    state.copyWith(metadata: _kit.buildMetadata(location: state.location)),
  );
}
