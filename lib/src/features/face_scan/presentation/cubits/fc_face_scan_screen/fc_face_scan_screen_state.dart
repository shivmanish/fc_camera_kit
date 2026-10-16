import 'package:equatable/equatable.dart';

import '../../../../../core/permissions/fc_permission_type.dart';
import '../../../../camera/domain/entities/fc_face_frame_status.dart';
import '../../../domain/entities/fc_face_result.dart';

sealed class FcFaceScanScreenState extends Equatable {
  const FcFaceScanScreenState();

  @override
  List<Object?> get props => [];
}

final class FcFaceScanPreparing extends FcFaceScanScreenState {
  const FcFaceScanPreparing();
}

/// The screen must request [required] and answer via `permissionResolved`.
final class FcFaceScanAskingPermission extends FcFaceScanScreenState {
  const FcFaceScanAskingPermission(this.required);

  final Set<FcPermissionType> required;

  @override
  List<Object?> get props => [required];
}

final class FcFaceScanActive extends FcFaceScanScreenState {
  const FcFaceScanActive(this.status, {this.canPop = true});

  final FcFaceFrameStatus status;

  /// `false` while the photo is processed.
  final bool canPop;

  @override
  List<Object?> get props => [status, canPop];
}

final class FcFaceScanLeaving extends FcFaceScanScreenState {
  const FcFaceScanLeaving({this.result, this.status});

  final FcFaceResult? result;

  /// Stays visible while the route closes so nothing flashes.
  final FcFaceFrameStatus? status;

  @override
  List<Object?> get props => [result, status];
}

/// Route couldn't close (first in the navigator): a static end screen.
final class FcFaceScanStranded extends FcFaceScanScreenState {
  const FcFaceScanStranded({required this.completed});

  final bool completed;

  @override
  List<Object?> get props => [completed];
}
