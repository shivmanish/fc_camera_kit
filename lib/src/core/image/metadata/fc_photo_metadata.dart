import 'package:equatable/equatable.dart';

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
    this.location,
    this.deviceModel,
    this.appId,
    this.note,
  });

  /// When the shutter fired. Store UTC if you need timezone-safe comparisons;
  /// the stamp renders whatever you pass.
  final DateTime capturedAt;

  /// Who — display name and stable id, from the configured user context.
  final String? userName;
  final String? userId;

  final FcGeoLocation? location;

  /// e.g. `Pixel 8 Pro`, for audit trails.
  final String? deviceModel;

  /// The host app that used the kit, e.g. `com.app.field`. EXIF only.
  final String? appId;

  /// Free-form extra line, appended to the stamp.
  final String? note;

  bool get hasLocation => location != null;
  bool get hasUser => userName != null || userId != null;

  FcPhotoMetadata copyWith({
    DateTime? capturedAt,
    String? userName,
    String? userId,
    FcGeoLocation? location,
    String? deviceModel,
    String? appId,
    String? note,
  }) => FcPhotoMetadata(
    capturedAt: capturedAt ?? this.capturedAt,
    userName: userName ?? this.userName,
    userId: userId ?? this.userId,
    location: location ?? this.location,
    deviceModel: deviceModel ?? this.deviceModel,
    appId: appId ?? this.appId,
    note: note ?? this.note,
  );

  @override
  List<Object?> get props => [
    capturedAt,
    userName,
    userId,
    location,
    deviceModel,
    appId,
    note,
  ];

  @override
  bool? get stringify => true;
}
