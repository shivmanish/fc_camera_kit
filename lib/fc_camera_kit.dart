/// Capture, stamp, compress and scan photos with who/when/where metadata.
///
/// Everything the host app is allowed to touch is exported here. Anything
/// under `src/` is private API and may change without a major version bump.
library;

// `FcResult` is a dartz `Either`, so callers need these types to destructure
// one. Re-exported so host apps need not depend on dartz themselves.
export 'package:dartz/dartz.dart' show Either, Left, Right;

// Config — the FcCameraKit singleton, FcUser and package defaults.
export 'src/core/config/fc_camera_kit.dart';
export 'src/core/config/fc_cubit.dart';
export 'src/core/config/fc_scan_options.dart';
// Errors — thrown by data sources, carried in Cubit state.
export 'src/core/error/fc_camera_exception.dart';
export 'src/core/error/fc_camera_failure.dart';
// Image pipeline — compression budget, lossless handoff, EXIF.
export 'src/core/image/compressor/fc_compression_policy.dart';
export 'src/core/image/compressor/fc_image_compressor.dart';
export 'src/core/image/fc_bmp_encoder.dart';
// Image metadata — the who / when / where attached to a capture.
export 'src/core/image/metadata/fc_exif_writer.dart';
export 'src/core/image/metadata/fc_geo_location.dart';
export 'src/core/image/metadata/fc_photo_metadata.dart';
// Permissions — gateways, one per permission.
export 'src/core/permissions/fc_camera_permission.dart';
export 'src/core/permissions/fc_location_permission.dart';
export 'src/core/permissions/fc_permission_status.dart';
export 'src/core/permissions/fc_permission_type.dart';
export 'src/core/permissions/fc_permissions.dart';
// Shared sheet and dialog chrome.
export 'src/core/ui/fc_ui.dart';
// Result plumbing.
export 'src/core/utils/fc_result.dart';

// Feature: permissions — the capture gate, its cubit and its surfaces.
// Feature: capture — acquiring a photo from camera or gallery.
export 'src/features/capture/cubit/fc_capture_cubit.dart';
export 'src/features/capture/cubit/fc_capture_state.dart';
export 'src/features/capture/fc_capture_flow.dart';
export 'src/features/capture/fc_capture_requirements.dart';
export 'src/features/capture/fc_capture_result.dart';
export 'src/features/capture/fc_capture_source.dart';
export 'src/features/capture/fc_image_source.dart';
export 'src/features/capture/widgets/fc_processing_screen.dart';
export 'src/features/capture/widgets/fc_source_sheet.dart';
export 'src/features/permissions/presentation/cubit/fc_permission_cubit.dart';
export 'src/features/permissions/presentation/cubit/fc_permission_state.dart';
export 'src/features/permissions/presentation/fc_permission_gate.dart';
export 'src/features/permissions/presentation/widgets/fc_location_service_dialog.dart';
export 'src/features/permissions/presentation/widgets/fc_permission_sheet.dart';
// Feature: scanner — document scan with edge detection, crop and filters.
export 'src/features/scanner/domain/entities/fc_scan_result.dart';
export 'src/features/scanner/domain/entities/fc_scan_stage.dart';
export 'src/features/scanner/domain/entities/fc_scan_stamp.dart';
export 'src/features/scanner/domain/repositories/fc_scan_repository.dart';
export 'src/features/scanner/fc_camera_kit_scan.dart';
export 'src/features/scanner/presentation/cubits/fc_scan/fc_scan_cubit.dart';
export 'src/features/scanner/presentation/cubits/fc_scan/fc_scan_state.dart';
export 'src/features/scanner/presentation/pages/fc_scanner_page.dart';
// Feature: stamping — draws who / when / where onto the pixels.
export 'src/features/stamping/cubit/fc_stamp_cubit.dart';
export 'src/features/stamping/cubit/fc_stamp_state.dart';
export 'src/features/stamping/fc_stamp_renderer.dart';
export 'src/features/stamping/fc_stamp_style.dart';

// Still to land, in phase order:
//   P4  core/image        ImageCompressor, CompressionPolicy, exif read/write
//   P5  features/capture
//   P6  features/stamping
//   P7  features/scanner
