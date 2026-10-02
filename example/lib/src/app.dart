import 'package:flutter/material.dart';

import 'home/home_page.dart';

/// Root of the demo app.
///
/// Ships a light and a dark scheme on purpose: every surface the kit renders
/// takes its colours from the host `ColorScheme`, and flipping the system theme
/// is the quickest way to see that it actually does.
class FcCameraKitExampleApp extends StatelessWidget {
  const FcCameraKitExampleApp({super.key});

  static const _seed = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SG Camera Kit',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const HomePage(),
    );
  }

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
