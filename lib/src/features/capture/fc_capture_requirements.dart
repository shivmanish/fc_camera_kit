import '../../core/permissions/fc_permission_type.dart';
import 'fc_capture_source.dart';

/// Which permissions a capture actually needs.
///
/// Scoped to the source and the configuration rather than asking for
/// everything up front: picking from the gallery with location switched off
/// needs no permission at all, and prompting anyway is the fastest way to get
/// a user to deny something they would otherwise have granted.
///
/// Gallery never asks for storage — `image_picker` goes through the Android
/// photo picker, which needs no permission.
Set<FcPermissionType> requirementsFor(
  FcCaptureSource source, {
  required bool requireLocation,
}) => {
  if (source == FcCaptureSource.camera) FcPermissionType.camera,
  if (requireLocation) FcPermissionType.location,
};
