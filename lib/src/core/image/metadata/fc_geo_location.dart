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
    this.fixedAt,
    this.isMocked = false,
  });

  /// How a mocked fix is marked, on the stamp and in EXIF.
  static const mockedMark = '(MOCKED)';

  final double latitude;
  final double longitude;

  /// Radius of 68% confidence, as reported by the platform.
  final double? accuracyMeters;
  final double? altitudeMeters;

  /// Human readable address from reverse geocoding.
  final String? address;

  /// When the platform took this fix. Older than the photo when the last
  /// known position stood in for a fresh one.
  final DateTime? fixedAt;

  /// The platform reported the fix as coming from a mock-location app. The
  /// photo is still taken; the stamp and EXIF carry [mockedMark].
  final bool isMocked;

  /// Signed decimal pair, e.g. `18.520430, 73.856743`.
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
