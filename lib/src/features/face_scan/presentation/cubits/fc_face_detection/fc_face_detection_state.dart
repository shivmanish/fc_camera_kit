import 'package:equatable/equatable.dart';

import '../../../domain/entities/fc_face_hint.dart';

sealed class FcFaceDetectionState extends Equatable {
  const FcFaceDetectionState();

  @override
  List<Object?> get props => [];
}

final class FcFaceDetectionSearching extends FcFaceDetectionState {
  const FcFaceDetectionSearching(this.hint);

  final FcFaceHint hint;

  @override
  List<Object?> get props => [hint];
}

final class FcFaceDetectionReady extends FcFaceDetectionState {
  const FcFaceDetectionReady();
}
