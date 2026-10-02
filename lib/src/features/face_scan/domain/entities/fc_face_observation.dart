import 'package:equatable/equatable.dart';

import 'fc_face_result.dart';

/// One face in one camera frame.
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

  /// 0–1; `null` when the detector couldn't classify that eye.
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// Same value across frames while the same face stays in view.
  final int? trackingId;

  @override
  List<Object?> get props => [box, pose, leftEyeOpen, rightEyeOpen, trackingId];
}
