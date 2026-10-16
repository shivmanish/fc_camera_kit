/// Permission only; the location service toggle is tracked separately.
enum FcPermissionStatus {
  granted,

  /// Approximate location (iOS 14+, Android 12+).
  grantedReduced,

  denied,

  /// The OS will not prompt again; only App Settings can fix it.
  deniedForever;

  bool get isUsable =>
      this == FcPermissionStatus.granted ||
      this == FcPermissionStatus.grantedReduced;

  bool get needsAppSettings => this == FcPermissionStatus.deniedForever;
}
