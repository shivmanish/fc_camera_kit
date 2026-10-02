import 'package:equatable/equatable.dart';

/// Face scan defaults, set once through `FcCameraKit.init(faceScan: ...)`.
final class FcFaceScanOptions extends Equatable {
  const FcFaceScanOptions({
    this.blinks = 1,
    this.embedMetadata = true,
    this.stamp = false,
    this.autoCaptureAfter = const Duration(seconds: 1),
    this.mirrorSelfie = true,
  });

  /// Blinks needed before the ring turns green. Must be positive.
  final int blinks;

  /// Writes who / when / where into the selfie's EXIF.
  final bool embedMetadata;

  /// Burns who / when / where onto the selfie, styled like `capture()`.
  /// Off by default: a selfie for identity is usually kept clean.
  final bool stamp;

  /// How long the ring stays green before the photo is taken by itself;
  /// `Duration.zero` leaves it to the shutter button.
  final Duration autoCaptureAfter;

  /// Saves the selfie as the user saw it in the mirrored preview. Off saves
  /// it as others see the person, left and right swapped from the preview.
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
