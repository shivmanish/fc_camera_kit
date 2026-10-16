import 'package:flutter/material.dart';

import 'home/home_page.dart';

/// Demo root; light and dark themes show the kit follows the host scheme.
class FcCameraKitExampleApp extends StatelessWidget {
  const FcCameraKitExampleApp({super.key});

  static const _seed = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FC Camera Kit',
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
