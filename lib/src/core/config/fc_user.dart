part of 'fc_camera_kit.dart';

/// Who is taking the photo, stamped onto captures and written to EXIF.
final class FcUser extends Equatable {
  const FcUser({
    required this.id,
    required this.name,
    required this.branch,
    this.role,
  });

  final String id;
  final String name;

  /// e.g. `Field Officer`; `null` when there is none.
  final String? role;

  /// The branch the user belongs to, e.g. `Baramati`. Pass `''` when there is
  /// none: a blank branch is left off the stamp and EXIF.
  final String branch;

  /// Pass [clearRole] to drop the role, since `role: null` keeps the current one.
  FcUser copyWith({
    String? id,
    String? name,
    String? role,
    String? branch,
    bool clearRole = false,
  }) => FcUser(
    id: id ?? this.id,
    name: name ?? this.name,
    role: clearRole ? null : role ?? this.role,
    branch: branch ?? this.branch,
  );

  @override
  List<Object?> get props => [id, name, role, branch];

  @override
  bool get stringify => true;
}

/// Reads and edits the signed-in user, whole or one field at a time.
extension FcUserConfig on FcCameraKit {
  /// Current user, or `null` if none is set.
  FcUser? get user => _user;

  set user(FcUser? user) => _user = user;

  /// Same as assigning [user]; kept for existing callers.
  void setUser(FcUser user) => _user = user;

  void clearUser() => _user = null;

  String? get userId => _user?.id;

  String? get userName => _user?.name;

  String? get userRole => _user?.role;

  String? get userBranch => _user?.branch;

  set userId(String id) => _user = _userOrBlank.copyWith(id: id);

  set userName(String name) => _user = _userOrBlank.copyWith(name: name);

  /// `null` or blank removes the role.
  set userRole(String? role) => _user = _userOrBlank.copyWith(
    role: role,
    clearRole: role == null || role.trim().isEmpty,
  );

  /// A blank branch is left off the stamp and EXIF.
  set userBranch(String branch) =>
      _user = _userOrBlank.copyWith(branch: branch);

  // Each field setter merges into the current user; setters are synchronous,
  // so consecutive calls never see a stale copy and need no lock.
  FcUser get _userOrBlank =>
      _user ?? const FcUser(id: '', name: '', branch: '');
}
