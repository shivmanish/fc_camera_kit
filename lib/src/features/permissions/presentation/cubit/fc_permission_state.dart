import 'package:equatable/equatable.dart';

import '../../../../core/permissions/fc_permission_status.dart';
import '../../../../core/permissions/fc_permission_type.dart';

final class FcPermissionState extends Equatable {
  const FcPermissionState({
    this.required = const {},
    this.statuses = const {},
    this.serviceEnabled = true,
    this.busy = false,
    this.loaded = false,
  });

  /// Kept so [allGranted] can check the statuses cover every requirement.
  final Set<FcPermissionType> required;

  final Map<FcPermissionType, FcPermissionStatus> statuses;

  final bool serviceEnabled;

  final bool busy;

  /// True after the first status read; [allGranted] is unreliable before.
  final bool loaded;

  bool get allGranted =>
      loaded && required.every((type) => statuses[type]?.isUsable ?? false);

  bool get needsAppSettings => statuses.values.any(
    (status) => !status.isUsable && status.needsAppSettings,
  );

  /// Declaration order, so rows keep their position.
  List<FcPermissionType> get ordered =>
      FcPermissionType.values.where(required.contains).toList();

  FcPermissionState copyWith({
    Set<FcPermissionType>? required,
    Map<FcPermissionType, FcPermissionStatus>? statuses,
    bool? serviceEnabled,
    bool? busy,
    bool? loaded,
  }) => FcPermissionState(
    required: required ?? this.required,
    statuses: statuses ?? this.statuses,
    serviceEnabled: serviceEnabled ?? this.serviceEnabled,
    busy: busy ?? this.busy,
    loaded: loaded ?? this.loaded,
  );

  @override
  List<Object?> get props => [required, statuses, serviceEnabled, busy, loaded];
}
