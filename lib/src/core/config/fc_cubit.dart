import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shared cubit base. Adds [safeEmit] (no-op after close) and an optional
///  runner for cubits that wrap a single use case.
abstract class FcCubit<S, T, P> extends Cubit<S> {
  FcCubit({required S initialState}) : super(initialState);

  @protected
  void safeEmit(S next) {
    if (!isClosed) emit(next);
  }
}
