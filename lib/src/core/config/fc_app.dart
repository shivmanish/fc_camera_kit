import 'package:equatable/equatable.dart';

enum FcEnvironment {
  production('PROD'),
  uat('UAT'),
  development('DEV');

  const FcEnvironment(this.label);

  final String label;
}

/// Host app identity written to EXIF `Software` and the stamp.
final class FcApp extends Equatable {
  const FcApp({
    required this.name,
    required this.version,
    required this.environment,
  });

  final String name;

  final String version;

  final FcEnvironment environment;

  bool get isProduction => environment == FcEnvironment.production;

  /// e.g. `FC Camera Kit Example 2.17.6 (UAT)`; no tag in production.
  String get software =>
      isProduction ? '$name $version' : '$name $version (${environment.label})';

  /// Non-production builds show the full build so test photos stand out.
  String get stampLine => isProduction ? name : software;

  @override
  List<Object?> get props => [name, version, environment];

  @override
  bool get stringify => true;
}
