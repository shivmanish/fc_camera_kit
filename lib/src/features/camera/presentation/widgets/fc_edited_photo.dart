import 'package:flutter/widgets.dart';

import '../../../../core/image/edit/fc_photo_edit.dart';

/// [image] turned and cropped by [edit], scaled to fit. Display only: the
/// pixels are cut once, when the photo is stamped.
class FcEditedPhoto extends StatelessWidget {
  const FcEditedPhoto({
    required this.image,
    required this.size,
    required this.edit,
    super.key,
  });

  final ImageProvider image;

  /// The upright photo's size, in pixels.
  final Size size;
  final FcPhotoEdit edit;

  @override
  Widget build(BuildContext context) {
    final turned = edit.turn(size);
    final crop = Rect.fromLTRB(
      edit.crop.left * turned.width,
      edit.crop.top * turned.height,
      edit.crop.right * turned.width,
      edit.crop.bottom * turned.height,
    );

    return FittedBox(
      child: SizedBox.fromSize(
        size: crop.size,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: turned.width,
            maxWidth: turned.width,
            minHeight: turned.height,
            maxHeight: turned.height,
            child: Transform.translate(
              offset: -crop.topLeft,
              child: RotatedBox(
                quarterTurns: edit.quarterTurns,
                child: Image(
                  image: image,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
