import 'package:equatable/equatable.dart';

/// Where a photo was taken; [address] is set only if geocoding succeeds.
final class FcGeoLocation extends Equatable {
  const FcGeoLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.address,
    this.fixedAt,
    this.isMocked = false,
  });

  static const mockedMark = '(MOCKED)';

  final double latitude;
  final double longitude;

  /// 68% confidence radius.
  final double? accuracyMeters;
  final double? altitudeMeters;

  final String? address;

  /// May predate the photo when a last-known position was used.
  final DateTime? fixedAt;

  final bool isMocked;

  String get coordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  FcGeoLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    double? altitudeMeters,
    String? address,
    DateTime? fixedAt,
    bool? isMocked,
  }) => FcGeoLocation(
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    accuracyMeters: accuracyMeters ?? this.accuracyMeters,
    altitudeMeters: altitudeMeters ?? this.altitudeMeters,
    address: address ?? this.address,
    fixedAt: fixedAt ?? this.fixedAt,
    isMocked: isMocked ?? this.isMocked,
  );

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    accuracyMeters,
    altitudeMeters,
    address,
    fixedAt,
    isMocked,
  ];

  @override
  bool? get stringify => true;
}
