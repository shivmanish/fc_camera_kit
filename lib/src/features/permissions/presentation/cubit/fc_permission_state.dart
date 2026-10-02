import 'package:equatable/equatable.dart';

import '../../../../core/permissions/fc_permission_status.dart';
import '../../../../core/permissions/fc_permission_type.dart';

/// Everything the permission sheet and dialog render from.
final class FcPermissionState extends Equatable {
  const FcPermissionState({
    this.required = const {},
    this.statuses = const {},
    this.serviceEnabled = true,
    this.busy = false,
    this.loaded = false,
  });

  /// What this gate demands. Kept in state so [allGranted] can verify the
  /// statuses actually *cover* it.
  final Set<FcPermissionType> required;

  final Map<FcPermissionType, FcPermissionStatus> statuses;

  /// Device-wide location toggle.
  final bool serviceEnabled;

  /// A request or a settings hand-off is in flight.
  final bool busy;

  /// First status read has completed, so [allGranted] is meaningful.
  final bool loaded;

  bool get allGranted =>
      loaded && required.every((type) => statuses[type]?.isUsable ?? false);

  /// True once a blocked permission can only be fixed from App Settings.
  bool get needsAppSettings => statuses.values.any(
    (status) => !status.isUsable && status.needsAppSettings,
  );

  /// Required types in declaration order, so rows never reshuffle.
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
