import 'package:equatable/equatable.dart';

final class FcFaceScanOptions extends Equatable {
  const FcFaceScanOptions({
    this.blinks = 1,
    this.embedMetadata = true,
    this.stamp = false,
    this.autoCaptureAfter = const Duration(seconds: 1),
    this.mirrorSelfie = true,
  });

  final int blinks;

  final bool embedMetadata;

  final bool stamp;

  /// `Duration.zero` disables auto capture.
  final Duration autoCaptureAfter;

  /// True saves the selfie as seen in the mirrored preview.
  final bool mirrorSelfie;

  FcFaceScanOptions copyWith({
    int? blinks,
    bool? embedMetadata,
    bool? stamp,
    Duration? autoCaptureAfter,
    bool? mirrorSelfie,
  }) => FcFaceScanOptions(
    blinks: blinks ?? this.blinks,
    embedMetadata: embedMetadata ?? this.embedMetadata,
    stamp: stamp ?? this.stamp,
    autoCaptureAfter: autoCaptureAfter ?? this.autoCaptureAfter,
    mirrorSelfie: mirrorSelfie ?? this.mirrorSelfie,
  );

  @override
  List<Object?> get props => [
    blinks,
    embedMetadata,
    stamp,
    autoCaptureAfter,
    mirrorSelfie,
  ];
}
