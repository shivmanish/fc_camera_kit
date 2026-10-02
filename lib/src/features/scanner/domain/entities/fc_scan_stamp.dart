import 'package:equatable/equatable.dart';

import '../../../../core/config/fc_camera_kit.dart';
import '../../../stamping/fc_stamp_style.dart';

/// How to stamp each scanned page; same settings `capture()` uses.
final class FcScanStamp extends Equatable {
  const FcScanStamp({
    required this.placement,
    required this.dateFormat,
    this.includeDevice = false,
    this.style = const FcStampStyle(),
  });

  final StampPlacement placement;
  final String dateFormat;
  final bool includeDevice;
  final FcStampStyle style;

  @override
  List<Object?> get props => [placement, dateFormat, includeDevice, style];
}
