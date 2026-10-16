import 'package:equatable/equatable.dart';

import '../../config/fc_app.dart';
import 'fc_geo_location.dart';

/// Who / when / where for one photo, passed to the stamp and EXIF steps.
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

  final DateTime capturedAt;

  final String? userName;
  final String? userId;
  final String? userRole;
  final String? userBranch;

  final FcGeoLocation? location;

  final String? deviceMake;

  final String? deviceModel;

  final FcApp? app;

  /// Set per file when EXIF is written; `null` before that.
  final String? imageId;

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
