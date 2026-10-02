import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/config/fc_cubit.dart';
import '../../../../core/permissions/fc_permission_type.dart';
import '../../../../core/permissions/fc_permissions.dart';
import 'fc_permission_state.dart';

/// Drives the permission sheet and the location-service dialog.
///
/// Owns an [AppLifecycleListener] so returning from App Settings re-checks
/// automatically — keeping that here is what lets both widgets stay stateless.
class FcPermissionCubit
    extends FcCubit<FcPermissionState, bool, Set<FcPermissionType>> {
  FcPermissionCubit({
    this.required = const {},
    FcPermissions? permissions,
    bool watchLifecycle = true,
  }) : _permissions = permissions ?? FcPermissions.instance,
       super(initialState: FcPermissionState(required: required)) {
    if (watchLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: refresh);
    }
    unawaited(refresh());
  }

  final Set<FcPermissionType> required;
  final FcPermissions _permissions;
  AppLifecycleListener? _lifecycle;

  /// Re-reads every status. Never prompts.
  ///
  /// Swallows platform errors on purpose: this runs unawaited from the
  /// constructor and from the lifecycle listener, where a throw would become
  /// an unhandled zone error and take the app down. A failed read simply
  /// leaves the previous statuses in place.
  Future<void> refresh() async {
    try {
      final statuses = await _permissions.statusOfAll(required);
      final serviceEnabled = required.contains(FcPermissionType.location)
          ? await _permissions.isLocationServiceEnabled()
          : true;

      safeEmit(
        state.copyWith(
          statuses: statuses,
          serviceEnabled: serviceEnabled,
          loaded: true,
        ),
      );
    } catch (_) {
      safeEmit(state.copyWith(loaded: true));
    }
  }

  /// Asks for each missing permission in turn, then re-reads.
  Future<void> requestAll() async {
    safeEmit(state.copyWith(busy: true));
    try {
      await _permissions.requestAll(required);
      await refresh();
    } finally {
      safeEmit(state.copyWith(busy: false));
    }
  }

  /// Hands off to App Settings. The lifecycle listener re-checks on return.
  Future<void> openAppSettings() async {
    safeEmit(state.copyWith(busy: true));
    try {
      await _permissions.openAppSettings();
    } finally {
      safeEmit(state.copyWith(busy: false));
    }
  }

  /// Hands off to device location settings.
  Future<void> openLocationSettings() async {
    safeEmit(state.copyWith(busy: true));
    try {
      await _permissions.openLocationSettings();
    } finally {
      safeEmit(state.copyWith(busy: false));
    }
  }

  @override
  Future<void> close() {
    _lifecycle?.dispose();
    _lifecycle = null;
    return super.close();
  }
}
