import 'package:equatable/equatable.dart';

import '../../../domain/entities/fc_face_hint.dart';

sealed class FcFaceDetectionState extends Equatable {
  const FcFaceDetectionState();

  @override
  List<Object?> get props => [];
}

/// Not ready yet: red ring, [hint] says why.
final class FcFaceDetectionSearching extends FcFaceDetectionState {
  const FcFaceDetectionSearching(this.hint);

  final FcFaceHint hint;

  @override
  List<Object?> get props => [hint];
}

/// One framed, straight face that has blinked: green ring.
final class FcFaceDetectionReady extends FcFaceDetectionState {
  const FcFaceDetectionReady();
}
