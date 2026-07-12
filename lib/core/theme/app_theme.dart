import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color debtColor = Color(0xFFC62828); // red — client owes money
  static const Color paidColor = Color(0xFF2E7D32); // green — settled / credit

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00695C));
    return ThemeData(
      colorScheme: scheme,
      // Large touch targets for quick daily use in a business setting.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
