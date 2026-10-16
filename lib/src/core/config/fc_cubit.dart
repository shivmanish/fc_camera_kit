import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Base cubit whose [safeEmit] is ignored once the cubit is closed.
abstract class FcCubit<S, T, P> extends Cubit<S> {
  FcCubit({required S initialState}) : super(initialState);

  @protected
  void safeEmit(S next) {
    if (!isClosed) emit(next);
  }
}
