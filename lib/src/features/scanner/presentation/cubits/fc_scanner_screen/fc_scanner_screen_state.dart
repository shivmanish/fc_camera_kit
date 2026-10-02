import 'package:equatable/equatable.dart';

import '../../../../../core/error/fc_camera_failure.dart';
import '../../../../../core/permissions/fc_permission_type.dart';
import '../../../domain/entities/fc_scan_result.dart';
import '../fc_scan/fc_scan_state.dart';

/// Everything the scanner screen shows, one phase at a time.
sealed class FcScannerScreenState extends Equatable {
  const FcScannerScreenState();

  @override
  List<Object?> get props => [];
}

/// Reading settings; the platform scanner hasn't opened yet.
final class FcScannerPreparing extends FcScannerScreenState {
  const FcScannerPreparing();
}

/// The screen must ask for [required]; it reports back with
/// `permissionResolved`.
final class FcScannerAskingPermission extends FcScannerScreenState {
  const FcScannerAskingPermission(this.required);

  final Set<FcPermissionType> required;

  @override
  List<Object?> get props => [required];
}

/// Scanning or preparing pages.
final class FcScannerActive extends FcScannerScreenState {
  const FcScannerActive(this.scan, {this.progress});

  final FcScanState scan;

  /// Last page progress; stays up until the route has closed.
  final FcScanProcessing? progress;

  bool get canPop => scan is! FcScanProcessing;

  @override
  List<Object?> get props => [scan, progress];
}

/// A failure the user can retry or close.
final class FcScannerFailed extends FcScannerScreenState {
  const FcScannerFailed(this.failure);

  final FcCameraFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// The flow has reported its outcome; the screen closes its route.
final class FcScannerLeaving extends FcScannerScreenState {
  const FcScannerLeaving({this.result, this.progress});

  final FcScanResult? result;
  final FcScanProcessing? progress;

  @override
  List<Object?> get props => [result, progress];
}

/// The route couldn't close (it is the navigator's first): a still end screen.
final class FcScannerStranded extends FcScannerScreenState {
  const FcScannerStranded({required this.completed});

  final bool completed;

  @override
  List<Object?> get props => [completed];
}
