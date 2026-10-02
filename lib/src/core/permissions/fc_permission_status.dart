/// Outcome of a permission check or request.
///
/// Richer than a bool because the recovery action differs: [denied] can be
/// asked again, [deniedForever] needs App Settings.
///
/// Deliberately says nothing about the device location toggle. That is a
/// separate axis — a granted permission with the service off is still granted,
/// and conflating them makes the gate show a permission sheet that cannot
/// possibly fix the problem.
enum FcPermissionStatus {
  /// Full precision granted.
  granted,

  /// Granted, but coordinates are approximate (iOS 14+, Android 12+).
  grantedReduced,

  /// Refused this time; asking again will show the dialog.
  denied,

  /// Refused for good. The dialog will not appear again.
  deniedForever;

  /// Whether a position can be read at all.
  bool get isUsable =>
      this == FcPermissionStatus.granted ||
      this == FcPermissionStatus.grantedReduced;

  /// Whether recovery requires sending the user to App Settings.
  bool get needsAppSettings => this == FcPermissionStatus.deniedForever;
}
