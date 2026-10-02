import 'package:equatable/equatable.dart';

/// Where a photo was taken. [address] is filled in only when reverse geocoding
/// succeeds, so treat it as optional even when coordinates are present.
final class FcGeoLocation extends Equatable {
  const FcGeoLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.altitudeMeters,
    this.address,
  });

  final double latitude;
  final double longitude;

  /// Radius of 68% confidence, as reported by the platform.
  final double? accuracyMeters;
  final double? altitudeMeters;

  /// Human readable address from reverse geocoding.
  final String? address;

  /// Signed decimal pair, e.g. `18.520430, 73.856743`.
  String get coordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  FcGeoLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    double? altitudeMeters,
    String? address,
  }) => FcGeoLocation(
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    accuracyMeters: accuracyMeters ?? this.accuracyMeters,
    altitudeMeters: altitudeMeters ?? this.altitudeMeters,
    address: address ?? this.address,
  );

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    accuracyMeters,
    altitudeMeters,
    address,
  ];

  @override
  bool? get stringify => true;
}
