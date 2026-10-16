import 'package:equatable/equatable.dart';

import 'fc_face_result.dart';

base class FcFaceObservation extends Equatable {
  const FcFaceObservation({
    required this.box,
    this.pose = const FcHeadPose(),
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.trackingId,
  });

  final FcFaceBox box;
  final FcHeadPose pose;

  /// 0–1, or `null` when that eye couldn't be classified.
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// Stable while the same face stays in view.
  final int? trackingId;

  @override
  List<Object?> get props => [box, pose, leftEyeOpen, rightEyeOpen, trackingId];
}
