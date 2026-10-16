import 'package:equatable/equatable.dart';

import '../../../../../core/permissions/fc_permission_type.dart';
import '../../../../camera/domain/entities/fc_face_frame_status.dart';
import '../../../domain/entities/fc_face_result.dart';

/// Everything the face scan screen shows, one phase at a time.
sealed class FcFaceScanScreenState extends Equatable {
  const FcFaceScanScreenState();

  @override
  List<Object?> get props => [];
}

/// Reading settings; nothing to show yet.
final class FcFaceScanPreparing extends FcFaceScanScreenState {
  const FcFaceScanPreparing();
}

/// The screen must ask for [required]; it reports back with
/// `permissionResolved`.
final class FcFaceScanAskingPermission extends FcFaceScanScreenState {
  const FcFaceScanAskingPermission(this.required);

  final Set<FcPermissionType> required;

  @override
  List<Object?> get props => [required];
}

/// The camera frame is on screen.
final class FcFaceScanActive extends FcFaceScanScreenState {
  const FcFaceScanActive(this.status, {this.canPop = true});

  final FcFaceFrameStatus status;

  /// `false` while the photo is being processed.
  final bool canPop;

  @override
  List<Object?> get props => [status, canPop];
}

/// The flow has reported its outcome; the screen closes its route.
final class FcFaceScanLeaving extends FcFaceScanScreenState {
  const FcFaceScanLeaving({this.result, this.status});

  final FcFaceResult? result;

  /// Kept on screen while the route closes, so nothing flashes.
  final FcFaceFrameStatus? status;

  @override
  List<Object?> get props => [result, status];
}

/// The route couldn't close (it is the navigator's first): a still end screen.
final class FcFaceScanStranded extends FcFaceScanScreenState {
  const FcFaceScanStranded({required this.completed});

  final bool completed;

  @override
  List<Object?> get props => [completed];
}
