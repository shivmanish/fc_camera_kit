import 'package:equatable/equatable.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';

class HomeState extends Equatable {
  const HomeState({
    this.user,
    this.statuses = const {},
    this.serviceEnabled = false,
    this.location,
    this.metadata,
    this.checkingAccess = false,
    this.locating = false,
    this.locationError,
    this.captures = const [],
    this.scans = const [],
    this.faces = const [],
    this.capturing = false,
    this.captureError,
    this.placement = StampPlacement.overlay,
    this.stampScans = false,
  });

  final FcUser? user;
  final Map<FcPermissionType, FcPermissionStatus> statuses;
  final bool serviceEnabled;
  final FcGeoLocation? location;

  /// What the stamper would receive right now.
  final FcPhotoMetadata? metadata;

  final bool checkingAccess;
  final bool locating;

  /// Last location failure, shown once then cleared.
  final FcCameraFailure? locationError;

  /// Every processed photo this session, newest first.
  final List<FcCaptureResult> captures;

  /// Every scanned page this session, newest first.
  final List<FcScannedPage> scans;

  /// Every face scan this session, newest first.
  final List<FcFaceResult> faces;

  /// The package is running a capture or a scan.
  final bool capturing;

  /// Last capture or scan failure, shown once then cleared.
  final FcCameraFailure? captureError;

  /// Mirrors `FcCameraKit.instance.placement`, so the control reflects the
  /// kit rather than keeping a second source of truth.
  final StampPlacement placement;

  /// Passed to each `scan()` and `scanFace()` call, so both modes can be
  /// tried side by side.
  final bool stampScans;

  bool get ready =>
      FcPermissions.captureDefaults.every(
        (type) => statuses[type]?.isUsable ?? false,
      ) &&
      serviceEnabled;

  HomeState copyWith({
    FcUser? user,
    bool clearUser = false,
    Map<FcPermissionType, FcPermissionStatus>? statuses,
    bool? serviceEnabled,
    FcGeoLocation? location,
    FcPhotoMetadata? metadata,
    bool? checkingAccess,
    bool? locating,
    FcCameraFailure? locationError,
    bool clearLocationError = false,
    List<FcCaptureResult>? captures,
    List<FcScannedPage>? scans,
    List<FcFaceResult>? faces,
    bool? capturing,
    FcCameraFailure? captureError,
    bool clearCaptureError = false,
    StampPlacement? placement,
    bool? stampScans,
  }) => HomeState(
    user: clearUser ? null : (user ?? this.user),
    statuses: statuses ?? this.statuses,
    serviceEnabled: serviceEnabled ?? this.serviceEnabled,
    location: location ?? this.location,
    metadata: metadata ?? this.metadata,
    checkingAccess: checkingAccess ?? this.checkingAccess,
    locating: locating ?? this.locating,
    locationError: clearLocationError
        ? null
        : (locationError ?? this.locationError),
    captures: captures ?? this.captures,
    scans: scans ?? this.scans,
    faces: faces ?? this.faces,
    capturing: capturing ?? this.capturing,
    captureError: clearCaptureError
        ? null
        : (captureError ?? this.captureError),
    placement: placement ?? this.placement,
    stampScans: stampScans ?? this.stampScans,
  );

  @override
  List<Object?> get props => [
    user,
    statuses,
    serviceEnabled,
    location,
    metadata,
    checkingAccess,
    locating,
    locationError,
    captures,
    scans,
    faces,
    capturing,
    captureError,
    placement,
    stampScans,
  ];
}
