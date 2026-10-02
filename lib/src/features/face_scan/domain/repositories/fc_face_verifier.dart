import '../entities/fc_face_capture.dart';
import '../entities/fc_face_verdict.dart';

/// Decides whether a selfie belongs to the right person, usually through the
/// host's own API.
abstract interface class FcFaceVerifier {
  Future<FcFaceVerdict> verify(FcFaceCapture capture);
}
