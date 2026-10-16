import 'package:dartz/dartz.dart';

import '../error/fc_camera_failure.dart';

/// Use-case result; `fold` takes failure first, [FcResultX.when] success first.
typedef FcResult<T> = Either<FcCameraFailure, T>;

FcResult<T> fcSuccess<T>(T value) => Right<FcCameraFailure, T>(value);

FcResult<T> fcFailure<T>(FcCameraFailure failure) =>
    Left<FcCameraFailure, T>(failure);

extension FcResultX<T> on FcResult<T> {
  bool get isSuccess => isRight();

  T? get valueOrNull => fold((_) => null, (value) => value);

  FcCameraFailure? get failureOrNull => fold((failure) => failure, (_) => null);

  R when<R>({
    required R Function(T value) success,
    required R Function(FcCameraFailure failure) failure,
  }) => fold(failure, success);
}

extension FcResultFuture<T> on Future<FcResult<T>> {
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
