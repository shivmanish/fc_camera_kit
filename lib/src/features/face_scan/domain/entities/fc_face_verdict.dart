import 'package:equatable/equatable.dart';

final class FcFaceVerdict extends Equatable {
  const FcFaceVerdict.approved({this.data = const {}})
    : approved = true,
      message = null;

  const FcFaceVerdict.rejected({this.message, this.data = const {}})
    : approved = false;

  final bool approved;

  /// User-facing reason; `null` when approved.
  final String? message;

  /// Raw verifier response, passed through.
  final Map<String, Object?> data;

  @override
  List<Object?> get props => [approved, message, data];
}
