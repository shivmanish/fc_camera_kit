part of 'fc_camera_kit.dart';

final class FcUser extends Equatable {
  const FcUser({
    required this.id,
    required this.name,
    required this.branch,
    this.role,
  });

  final String id;
  final String name;

  final String? role;

  /// Pass `''` for none; a blank branch is omitted from stamp and EXIF.
  final String branch;

  /// `role: null` keeps the role; use [clearRole] to drop it.
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

extension FcUserConfig on FcCameraKit {
  FcUser? get user => _user;

  set user(FcUser? user) => _user = user;

  void setUser(FcUser user) => _user = user;

  void clearUser() => _user = null;

  String? get userId => _user?.id;

  String? get userName => _user?.name;

  String? get userRole => _user?.role;

  String? get userBranch => _user?.branch;

  set userId(String id) => _user = _userOrBlank.copyWith(id: id);

  set userName(String name) => _user = _userOrBlank.copyWith(name: name);

  /// `null` or blank clears the role.
  set userRole(String? role) => _user = _userOrBlank.copyWith(
    role: role,
    clearRole: role == null || role.trim().isEmpty,
  );

  set userBranch(String branch) =>
      _user = _userOrBlank.copyWith(branch: branch);

  // Setters are synchronous, so successive merges never see a stale copy.
  FcUser get _userOrBlank =>
      _user ?? const FcUser(id: '', name: '', branch: '');
}
