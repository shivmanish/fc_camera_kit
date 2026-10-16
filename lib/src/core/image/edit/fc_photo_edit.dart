import 'dart:ui';

import 'package:equatable/equatable.dart';

/// Non-destructive rotate-then-crop, applied only when the stamp is drawn.
final class FcPhotoEdit extends Equatable {
  const FcPhotoEdit({this.quarterTurns = 0, this.crop = fullFrame});

  static const none = FcPhotoEdit();
  static const fullFrame = Rect.fromLTWH(0, 0, 1, 1);

  /// Clockwise, 0–3.
  final int quarterTurns;

  /// Fractions of the turned photo.
  final Rect crop;

  bool get isNone => quarterTurns == 0 && crop == fullFrame;

  Size turn(Size size) => quarterTurns.isOdd ? size.flipped : size;

  // The crop rotates with the photo.
  FcPhotoEdit rotatedLeft() => FcPhotoEdit(
    quarterTurns: (quarterTurns + 3) % 4,
    crop: Rect.fromLTWH(crop.top, 1 - crop.right, crop.height, crop.width),
  );

  FcPhotoEdit withCrop(Rect crop) =>
      FcPhotoEdit(quarterTurns: quarterTurns, crop: crop);

  @override
  List<Object?> get props => [quarterTurns, crop];
}
