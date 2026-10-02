import 'package:dartz/dartz.dart';

import '../error/fc_camera_failure.dart';

/// Result of every use case. Failure on the left, value on the right.
///
/// Note `fold` takes the failure branch first — use [FcResultX.when] if that
/// ordering is easy to get wrong.
typedef FcResult<T> = Either<FcCameraFailure, T>;

/// Success, with the failure type inferred.
FcResult<T> fcSuccess<T>(T value) => Right<FcCameraFailure, T>(value);

/// Failure, with the value type inferred.
FcResult<T> fcFailure<T>(FcCameraFailure failure) =>
    Left<FcCameraFailure, T>(failure);

extension FcResultX<T> on FcResult<T> {
  bool get isSuccess => isRight();

  T? get valueOrNull => fold((_) => null, (value) => value);

  FcCameraFailure? get failureOrNull => fold((failure) => failure, (_) => null);

  /// Success-first alternative to `fold`, with named branches.
  R when<R>({
    required R Function(T value) success,
    required R Function(FcCameraFailure failure) failure,
  }) => fold(failure, success);
}

extension FcResultFuture<T> on Future<FcResult<T>> {
  /// Chains a fallible async step, short-circuiting on the first failure.
  Future<FcResult<R>> thenFlatMap<R>(
    Future<FcResult<R>> Function(T value) next,
  ) async {
    final result = await this;
    return result.fold<Future<FcResult<R>>>(
      (failure) async => fcFailure<R>(failure),
      next,
    );
  }

  Future<FcResult<R>> thenMap<R>(R Function(T value) transform) async =>
      (await this).map(transform);
}
