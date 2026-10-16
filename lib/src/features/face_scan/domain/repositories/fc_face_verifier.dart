import '../entities/fc_face_capture.dart';
import '../entities/fc_face_verdict.dart';

/// Checks the selfie belongs to the right person, typically via the host's API.
abstract interface class FcFaceVerifier {
  Future<FcFaceVerdict> verify(FcFaceCapture capture);
}
