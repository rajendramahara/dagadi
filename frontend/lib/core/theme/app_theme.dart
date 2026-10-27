import 'package:flutter/material.dart';

/// Central theme definition. No screen should set colors/fonts inline -
/// everything comes from Theme.of(context) so dark mode and future brand
/// tweaks require editing only this file.
class AppTheme {
  static const Color brandGreen = Color(0xFF1B7A4A);
  static const Color brandGreenDark = Color(0xFF0F5C36);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandGreen,
      brightness: Brightness.light,
    );
    return _base(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandGreen,
      brightness: Brightness.dark,
    );
    return _base(colorScheme);
  }

  static ThemeData _base(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.55),
      textTheme:
          ThemeData(brightness: colorScheme.brightness).textTheme.copyWith(
                headlineSmall: const TextStyle(
                    fontSize: 25, height: 1.15, fontWeight: FontWeight.w700),
                titleLarge: const TextStyle(
                    fontSize: 20, height: 1.2, fontWeight: FontWeight.w700),
                titleMedium: const TextStyle(
                    fontSize: 16, height: 1.25, fontWeight: FontWeight.w600),
                bodyMedium: const TextStyle(fontSize: 14, height: 1.35),
                labelLarge:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: brandGreen.withValues(alpha: 0.15),
        height: 70,
        labelTextStyle: WidgetStatePropertyAll(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
