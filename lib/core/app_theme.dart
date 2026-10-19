import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF0B1B33);
  static const cobalt = Color(0xFF3D5AFE);
  static const mist = Color(0xFFF3F5FA);
  static const cloud = Color(0xFFFFFFFF);

  static const safe = Color(0xFF1FB57A);
  static const caution = Color(0xFFF59E0B);
  static const danger = Color(0xFFF0455A);

  static const mutedLight = Color(0xFF6B7A90);

  static const nightBg = Color(0xFF0A111F);
  static const nightSurface = Color(0xFF131C2E);
  static const nightText = Color(0xFFEAF0FA);
  static const mutedDark = Color(0xFF93A1B8);
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.nightBg : AppColors.mist;
    final surface = isDark ? AppColors.nightSurface : AppColors.cloud;
    final onSurface = isDark ? AppColors.nightText : AppColors.ink;
    final muted = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.cobalt,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.cobalt,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
    );

    final text = TextTheme(
      displaySmall: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.1,
          color: onSurface),
      headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: onSurface),
      titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: onSurface),
      titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: onSurface),
      titleSmall: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w400, height: 1.4, color: onSurface),
      bodyMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400, height: 1.4, color: onSurface),
      bodySmall: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: muted),
      labelLarge: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: text,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.cobalt, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cobalt,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: muted.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}