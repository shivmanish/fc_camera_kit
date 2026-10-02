import 'package:cross_file/cross_file.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/fc_camera_failure.dart';
import '../../../domain/entities/fc_scan_result.dart';
import '../../../domain/entities/fc_scan_stage.dart';

sealed class FcScanState extends Equatable {
  const FcScanState();

  @override
  List<Object?> get props => [];
}

final class FcScanIdle extends FcScanState {
  const FcScanIdle();
}

/// The platform scanner is on screen.
final class FcScanScanning extends FcScanState {
  const FcScanScanning();
}

final class FcScanProcessing extends FcScanState {
  const FcScanProcessing({
    required this.page,
    required this.total,
    required this.preview,
    this.stages = const [],
    this.stage,
  });

  /// 1-based.
  final int page;
  final int total;

  /// The page being prepared, shown behind the progress.
  final XFile preview;

  /// Every step this page goes through, in order.
  final List<FcScanStage> stages;

  /// The running step; `null` before the first one starts.
  final FcScanStage? stage;

  @override
  List<Object?> get props => [page, total, preview.path, stages, stage];
}

final class FcScanSuccess extends FcScanState {
  const FcScanSuccess(this.result);

  final FcScanResult result;

  @override
  List<Object?> get props => [result];
}

/// Includes the user backing out, as a `CancelledFailure`.
final class FcScanError extends FcScanState {
  const FcScanError(this.failure);

  final FcCameraFailure failure;

  @override
  List<Object?> get props => [failure];
}
