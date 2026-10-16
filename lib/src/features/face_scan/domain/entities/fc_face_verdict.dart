import 'package:equatable/equatable.dart';

/// What a verifier decided about a selfie.
final class FcFaceVerdict extends Equatable {
  const FcFaceVerdict.approved({this.data = const {}})
    : approved = true,
      message = null;

  const FcFaceVerdict.rejected({this.message, this.data = const {}})
    : approved = false;

  final bool approved;

  /// Why it was rejected, for the user; `null` when approved.
  final String? message;

  /// Whatever the verifier returned, handed back untouched.
  final Map<String, Object?> data;

  @override
  List<Object?> get props => [approved, message, data];
}
