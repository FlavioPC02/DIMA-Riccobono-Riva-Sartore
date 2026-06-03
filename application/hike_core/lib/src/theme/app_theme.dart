import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class AppTheme {
  static ColorScheme get lightColorScheme => ColorScheme.fromSeed(
    seedColor: Color(0xFFFFFFFF),
    primary: Color(0xFFE95F2A),
    secondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFFE1E1E1),
    shadow: Color(0xFF000000),
    onSecondary: Color(0xFF21211F),
    surface: Color(0xFF111C18),
  );

  static ColorScheme get darkColorScheme => ColorScheme.fromSeed(
    seedColor: Color(0xFF21211F),
    primary: Color(0xFFE95F2A),
    secondary: Color(0xFF21211F),
    tertiary: Color(0xFF141414),
    shadow: Color(0xFFAAAAAA),
    onSecondary: Color(0xFFFFFFFF),
    surface: Color(0xFF111C18),
    brightness: Brightness.dark,
  );

  static SwitchThemeData buildSwitchTheme(ColorScheme colorScheme) {
    return SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return null;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.secondary;
        }
        return null;
      }),
    );
  }

  static ElevatedButtonThemeData buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const ui.Size(double.infinity, 50),
        shape: const StadiumBorder(),
      ),
    );
  }

  static TextTheme buildTextTheme() {
    return TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 16),
    );
  }

  static InputDecorationTheme buildInputDecorationTheme() {
    return InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}