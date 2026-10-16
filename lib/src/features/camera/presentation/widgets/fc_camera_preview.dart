import 'package:flutter/widgets.dart';

import '../../data/datasources/fc_live_camera.dart';
import '../../domain/entities/fc_face_frame_geometry.dart';

/// The live preview filling its box without stretching: scaled to cover and
/// cropped, keeping the sensor's real proportions in either orientation.
class FcCameraPreview extends StatelessWidget {
  const FcCameraPreview({
    required this.camera,
    required this.sensorAspect,
    super.key,
  });

  final FcLiveCamera camera;

  /// Width ÷ height of the sensor's frames (landscape, so above 1).
  final double sensorAspect;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = FcFaceFrameGeometry.uprightAspect(
      sensorAspect,
      landscape: MediaQuery.orientationOf(context) == Orientation.landscape,
    );
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1000 * aspectRatio,
            height: 1000,
            child: camera.buildPreview(),
          ),
        ),
      ),
    );
  }
}
