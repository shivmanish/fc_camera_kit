import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/config/fc_cubit.dart';
import '../../../../core/permissions/fc_permission_type.dart';
import '../../../../core/permissions/fc_permissions.dart';
import 'fc_permission_state.dart';

/// Permission statuses, re-read on app resume after a settings visit.
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

  /// Never prompts; swallows errors because it runs unawaited.
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

  Future<void> requestAll() async {
    safeEmit(state.copyWith(busy: true));
    try {
      await _permissions.requestAll(required);
      await refresh();
    } finally {
      safeEmit(state.copyWith(busy: false));
    }
  }

  Future<void> openAppSettings() async {
    safeEmit(state.copyWith(busy: true));
    try {
      await _permissions.openAppSettings();
    } finally {
      safeEmit(state.copyWith(busy: false));
    }
  }

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
