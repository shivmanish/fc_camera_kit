import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/image/metadata/fc_photo_metadata.dart';
import 'fc_face_verdict.dart';

/// Face box as 0–1 fractions of the upright photo.
final class FcFaceBox extends Equatable {
  const FcFaceBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  @override
  List<Object?> get props => [left, top, width, height];
}

/// Degrees: yaw turns left/right, pitch nods, roll tilts.
final class FcHeadPose extends Equatable {
  const FcHeadPose({this.yaw = 0, this.pitch = 0, this.roll = 0});

  final double yaw;
  final double pitch;
  final double roll;

  @override
  List<Object?> get props => [yaw, pitch, roll];
}

final class FcFaceResult extends Equatable {
  const FcFaceResult({
    required this.file,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.capturedAt,
    required this.livenessPassed,
    required this.face,
    required this.pose,
    required this.stamped,
    this.metadata,
    this.verdict,
  });

  /// Unmirrored, upright and under the size budget.
  final XFile file;
  final int width;
  final int height;
  final int sizeBytes;
  final DateTime capturedAt;

  final bool livenessPassed;
  final FcFaceBox face;
  final FcHeadPose pose;

  final bool stamped;

  final FcPhotoMetadata? metadata;

  /// `null` for offline scans.
  final FcFaceVerdict? verdict;

  double get sizeKb => sizeBytes / 1024;
  double get sizeMb => sizeBytes / (1024 * 1024);

  @override
  List<Object?> get props => [
    file.path,
    width,
    height,
    sizeBytes,
    capturedAt,
    livenessPassed,
    face,
    pose,
    stamped,
    metadata,
    verdict,
  ];
}
