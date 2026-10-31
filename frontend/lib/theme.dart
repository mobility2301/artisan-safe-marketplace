// DESTINATION: lib/theme.dart
import 'package:flutter/material.dart';
 
/// The colours of Artisan Safe. Indigo is the dye of the Nsukka and Igbo cloth tradition;
/// gold marks the one action on a screen; lagoon green is kept for "verified".
class Brand {
  static const Color indigo = Color(0xFF1F2B5C);
  static const Color ink = Color(0xFF12162B);
  static const Color paper = Color(0xFFF6F7FB);
  static const Color gold = Color(0xFFF2B544);
  static const Color lagoon = Color(0xFF1E8E6E);
  static const Color line = Color(0xFFD9DDEB);
  static const Color muted = Color(0xFF5A6280);
}
 
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.indigo,
    brightness: Brightness.light,
  ).copyWith(
    primary: Brand.indigo,
    onPrimary: Colors.white,
    secondary: Brand.gold,
    tertiary: Brand.lagoon,
  );
 
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.paper,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}