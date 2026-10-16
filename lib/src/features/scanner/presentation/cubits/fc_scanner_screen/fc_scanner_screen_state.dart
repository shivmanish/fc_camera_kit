import 'package:equatable/equatable.dart';

import '../../../../../core/error/fc_camera_failure.dart';
import '../../../../../core/permissions/fc_permission_type.dart';
import '../../../domain/entities/fc_scan_result.dart';
import '../fc_scan/fc_scan_state.dart';

sealed class FcScannerScreenState extends Equatable {
  const FcScannerScreenState();

  @override
  List<Object?> get props => [];
}

final class FcScannerPreparing extends FcScannerScreenState {
  const FcScannerPreparing();
}

/// Answered through `permissionResolved`.
final class FcScannerAskingPermission extends FcScannerScreenState {
  const FcScannerAskingPermission(this.required);

  final Set<FcPermissionType> required;

  @override
  List<Object?> get props => [required];
}

final class FcScannerActive extends FcScannerScreenState {
  const FcScannerActive(this.scan, {this.progress});

  final FcScanState scan;

  /// Kept until the route closes.
  final FcScanProcessing? progress;

  bool get canPop => scan is! FcScanProcessing;

  @override
  List<Object?> get props => [scan, progress];
}

final class FcScannerFailed extends FcScannerScreenState {
  const FcScannerFailed(this.failure);

  final FcCameraFailure failure;

  @override
  List<Object?> get props => [failure];
}

final class FcScannerLeaving extends FcScannerScreenState {
  const FcScannerLeaving({this.result, this.progress});

  final FcScanResult? result;
  final FcScanProcessing? progress;

  @override
  List<Object?> get props => [result, progress];
}

/// The route is the navigator's first and cannot close.
final class FcScannerStranded extends FcScannerScreenState {
  const FcScannerStranded({required this.completed});

  final bool completed;

  @override
  List<Object?> get props => [completed];
}
