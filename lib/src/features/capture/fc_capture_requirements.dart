import '../../core/permissions/fc_permission_type.dart';
import 'fc_capture_source.dart';

/// Permissions scoped to source and config, so users are never over-prompted.
/// Gallery needs no storage permission: it uses the Android photo picker.
Set<FcPermissionType> requirementsFor(
  FcCaptureSource source, {
  required bool requireLocation,
}) => {
  if (source == FcCaptureSource.camera) FcPermissionType.camera,
  if (requireLocation) FcPermissionType.location,
};
