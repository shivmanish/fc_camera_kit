/// A permission the kit can require before a capture.
enum FcPermissionType {
  camera(label: 'Camera', reason: 'To take the photo.'),
  location(label: 'Location', reason: 'To stamp where the photo was taken.');

  const FcPermissionType({required this.label, required this.reason});

  /// Short name shown in the permission sheet.
  final String label;

  /// One line explaining why the kit asks for it.
  final String reason;
}
