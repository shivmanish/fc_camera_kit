import 'package:equatable/equatable.dart';

/// Which build of the host app a photo came from.
enum FcEnvironment {
  production('PROD'),
  uat('UAT'),
  development('DEV');

  const FcEnvironment(this.label);

  /// The tag shown beside the version outside production.
  final String label;
}

/// The host app, as its photos record it: EXIF `Software` and a stamp line.
///
/// One shape for every host app, so their photos all read the same.
final class FcApp extends Equatable {
  const FcApp({
    required this.name,
    required this.version,
    required this.environment,
  });

  /// e.g. `SarvaSarathi COS`.
  final String name;

  /// e.g. `2.17.6` — `PackageInfo.version` in the host app.
  final String version;

  /// Required, so a UAT build cannot pass for production by omission.
  final FcEnvironment environment;

  bool get isProduction => environment == FcEnvironment.production;

  /// EXIF `Software`, always with the version so a photo traces back to its
  /// build: `SarvaSarathi COS 2.17.6`, or `SarvaSarathi COS 2.17.6 (UAT)`.
  String get software =>
      isProduction ? '$name $version' : '$name $version (${environment.label})';

  /// The stamp line: the name alone in production. Outside it the build is
  /// called out, so a test photo can never pass for a real one.
  String get stampLine => isProduction ? name : software;

  @override
  List<Object?> get props => [name, version, environment];

  @override
  bool get stringify => true;
}
