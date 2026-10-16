import 'dart:ui';

import 'package:equatable/equatable.dart';

/// A non-destructive edit: turn the photo by quarter turns, then crop.
///
/// Kept as numbers rather than pixels until the stamp step draws the photo,
/// so editing costs no extra decode, no extra encode and no quality.
final class FcPhotoEdit extends Equatable {
  const FcPhotoEdit({this.quarterTurns = 0, this.crop = fullFrame});

  static const none = FcPhotoEdit();
  static const fullFrame = Rect.fromLTWH(0, 0, 1, 1);

  /// Clockwise quarter turns, 0–3.
  final int quarterTurns;

  /// The part kept, as fractions of the turned photo.
  final Rect crop;

  bool get isNone => quarterTurns == 0 && crop == fullFrame;

  /// A photo of [size] after the turn.
  Size turn(Size size) => quarterTurns.isOdd ? size.flipped : size;

  /// A quarter turn anticlockwise, the crop carried round with the photo.
  FcPhotoEdit rotatedLeft() => FcPhotoEdit(
    quarterTurns: (quarterTurns + 3) % 4,
    crop: Rect.fromLTWH(crop.top, 1 - crop.right, crop.height, crop.width),
  );

  FcPhotoEdit withCrop(Rect crop) =>
      FcPhotoEdit(quarterTurns: quarterTurns, crop: crop);

  @override
  List<Object?> get props => [quarterTurns, crop];
}
