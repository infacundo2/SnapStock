import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF0B0D10);
  static const surface = Color(0xFF15181D);
  static const surfaceRaised = Color(0xFF1D2128);
  static const border = Color(0xFF303640);
  static const primary = Color(0xFFD44242);
  static const primaryStrong = Color(0xFFB7262E);
  static const success = Color(0xFF49B982);
  static const warning = Color(0xFFE2A84B);
  static const textMuted = Color(0xFFA8AFBA);
}

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    ).copyWith(
      primary: AppColors.primary,
      secondary: const Color(0xFFFF7777),
      surface: AppColors.surface,
      error: const Color(0xFFFF6B6B),
      outline: AppColors.border,
    );

    final baseText = ThemeData(brightness: Brightness.dark).textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseText.copyWith(
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium:
            baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: baseText.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: baseText.bodyMedium?.copyWith(height: 1.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        prefixIconColor: AppColors.textMuted,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: const TextStyle(color: Color(0xFF777F8B)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryStrong,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryStrong,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryStrong,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: Color(0x33202020),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
