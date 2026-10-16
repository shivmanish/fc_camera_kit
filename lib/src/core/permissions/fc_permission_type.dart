enum FcPermissionType {
  camera(label: 'Camera', reason: 'To take the photo.'),
  location(label: 'Location', reason: 'To stamp where the photo was taken.');

  const FcPermissionType({required this.label, required this.reason});

  final String label;

  final String reason;
}
