/// Public API: capture, stamp, compress and scan photos with metadata.
library;

// Re-exported so hosts can unpack `FcResult` without adding dartz.
export 'package:dartz/dartz.dart' show Either, Left, Right;

// App
export 'src/core/config/fc_app.dart';
// Config
export 'src/core/config/fc_camera_kit.dart';
export 'src/core/config/fc_cubit.dart';
export 'src/core/config/fc_face_scan_options.dart';
export 'src/core/config/fc_scan_options.dart';
// Errors
export 'src/core/error/fc_camera_exception.dart';
export 'src/core/error/fc_camera_failure.dart';
// Image compression
export 'src/core/image/compressor/fc_compression_policy.dart';
export 'src/core/image/compressor/fc_image_compressor.dart';
export 'src/core/image/fc_bmp_encoder.dart';
// Image pipeline
export 'src/core/image/fc_image_pipeline.dart';
// Image metadata
export 'src/core/image/metadata/fc_exif_writer.dart';
export 'src/core/image/metadata/fc_geo_location.dart';
export 'src/core/image/metadata/fc_photo_metadata.dart';
// Stamp
export 'src/core/image/stamp/fc_stamp_renderer.dart';
export 'src/core/image/stamp/fc_stamp_style.dart';
// Permissions
export 'src/core/permissions/fc_camera_permission.dart';
export 'src/core/permissions/fc_location_permission.dart';
export 'src/core/permissions/fc_permission_status.dart';
export 'src/core/permissions/fc_permission_type.dart';
export 'src/core/permissions/fc_permissions.dart';
// Shared UI
export 'src/core/ui/fc_ui.dart';
// Utils
export 'src/core/utils/fc_result.dart';
// Feature: capture
export 'src/features/capture/fc_capture_flow.dart';
export 'src/features/capture/fc_capture_requirements.dart';
export 'src/features/capture/fc_capture_result.dart';
export 'src/features/capture/fc_capture_source.dart';
export 'src/features/capture/fc_image_source.dart';
export 'src/features/capture/widgets/fc_processing_screen.dart';
export 'src/features/capture/widgets/fc_source_sheet.dart';
// Feature: face scan
export 'src/features/face_scan/domain/entities/fc_face_result.dart';
export 'src/features/face_scan/domain/entities/fc_face_verdict.dart';
export 'src/features/face_scan/fc_camera_kit_face_scan.dart';
export 'src/features/face_scan/presentation/pages/fc_face_scan_page.dart';
// Feature: permissions
export 'src/features/permissions/presentation/cubit/fc_permission_cubit.dart';
export 'src/features/permissions/presentation/cubit/fc_permission_state.dart';
export 'src/features/permissions/presentation/fc_permission_gate.dart';
export 'src/features/permissions/presentation/widgets/fc_location_service_dialog.dart';
export 'src/features/permissions/presentation/widgets/fc_permission_sheet.dart';
// Feature: scanner
export 'src/features/scanner/domain/entities/fc_scan_result.dart';
export 'src/features/scanner/domain/entities/fc_scan_stage.dart';
export 'src/features/scanner/domain/entities/fc_scan_stamp.dart';
export 'src/features/scanner/domain/repositories/fc_scan_repository.dart';
export 'src/features/scanner/fc_camera_kit_scan.dart';
export 'src/features/scanner/presentation/cubits/fc_scan/fc_scan_cubit.dart';
export 'src/features/scanner/presentation/cubits/fc_scan/fc_scan_state.dart';
export 'src/features/scanner/presentation/pages/fc_scanner_page.dart';
// Feature: stamping
export 'src/features/stamping/cubit/fc_stamp_cubit.dart';
export 'src/features/stamping/cubit/fc_stamp_state.dart';
