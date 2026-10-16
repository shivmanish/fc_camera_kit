import 'package:equatable/equatable.dart';

import '../../config/fc_app.dart';
import 'fc_geo_location.dart';

/// Resolved who / when / where for one photo.
///
/// Built once per capture, then passed explicitly to the stamper and the EXIF
/// writer — neither reads global state. Every field except [capturedAt] is
/// optional, since location can time out and the user context may be unset.
final class FcPhotoMetadata extends Equatable {
  const FcPhotoMetadata({
    required this.capturedAt,
    this.userName,
    this.userId,
    this.userRole,
    this.userBranch,
    this.location,
    this.deviceMake,
    this.deviceModel,
    this.app,
    this.imageId,
    this.note,
  });

  /// When the shutter fired. Store UTC if you need timezone-safe comparisons;
  /// the stamp renders whatever you pass.
  final DateTime capturedAt;

  /// Who — display name, stable id, role and branch, from the configured user
  /// context.
  final String? userName;
  final String? userId;
  final String? userRole;
  final String? userBranch;

  final FcGeoLocation? location;

  /// The handset maker, e.g. `Google`, for audit trails.
  final String? deviceMake;

  /// The handset model, e.g. `Pixel 8 Pro`, for audit trails.
  final String? deviceModel;

  /// The host app that used the kit: EXIF `Software` and a stamp line.
  final FcApp? app;

  /// The photo's own id, 32 hex digits, also in EXIF `ImageUniqueID`. Set
  /// when EXIF is written, one per file; `null` before that.
  final String? imageId;

  /// Free-form extra line, appended to the stamp.
  final String? note;

  bool get hasLocation => location != null;
  bool get hasUser =>
      userName != null ||
      userId != null ||
      userRole != null ||
      userBranch != null;

  FcPhotoMetadata copyWith({
    DateTime? capturedAt,
    String? userName,
    String? userId,
    String? userRole,
    String? userBranch,
    FcGeoLocation? location,
    String? deviceMake,
    String? deviceModel,
    FcApp? app,
    String? imageId,
    String? note,
  }) => FcPhotoMetadata(
    capturedAt: capturedAt ?? this.capturedAt,
    userName: userName ?? this.userName,
    userId: userId ?? this.userId,
    userRole: userRole ?? this.userRole,
    userBranch: userBranch ?? this.userBranch,
    location: location ?? this.location,
    deviceMake: deviceMake ?? this.deviceMake,
    deviceModel: deviceModel ?? this.deviceModel,
    app: app ?? this.app,
    imageId: imageId ?? this.imageId,
    note: note ?? this.note,
  );

  @override
  List<Object?> get props => [
    capturedAt,
    userName,
    userId,
    userRole,
    userBranch,
    location,
    deviceMake,
    deviceModel,
    app,
    imageId,
    note,
  ];

  @override
  bool? get stringify => true;
}
