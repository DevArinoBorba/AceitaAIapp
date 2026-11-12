import 'package:flutter/material.dart';

import '../../domain/entities/verdict.dart';

/// Paleta "cockpit": fundo quase preto, verde de aprovação, âmbar de atenção,
/// vermelho de recusa. O app é dark-first (como o GigU) — tema claro fica
/// para depois, quando houver demanda real.
class AppColors {
  const AppColors._();

  static const bg = Color(0xFF070708);
  static const surface = Color(0xFF151516);
  static const surfaceAlt = Color(0xFF232325);
  static const border = Color(0xFF444448);

  static const primary = Color(0xFFE6E7E9);
  static const primaryInk = Color(0xFF080809);

  static const good = Color(0xFFE6E7E9);
  static const average = Color(0xFFB7B8BC);
  static const bad = Color(0xFFFF5A5F);

  static const text = Color(0xFFF3F3F4);
  static const muted = Color(0xFFB3B3BA);

  static const chrome = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFE4E5E7), Color(0xFFA9ABB0)],
    stops: [0, 0.42, 1],
  );

  static const panel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A2B2D), Color(0xFF161617), Color(0xFF09090A)],
    stops: [0, 0.4, 1],
  );
}

Color gradeColor(Grade grade) => switch (grade) {
      Grade.bad => AppColors.bad,
      Grade.average => AppColors.average,
      Grade.good => AppColors.good,
    };

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.primaryInk,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    secondary: AppColors.primary,
    secondaryContainer: AppColors.primary,
    onSecondaryContainer: AppColors.primaryInk,
    surfaceContainerHighest: AppColors.surfaceAlt,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.bad,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Roboto'),
    ),
  );
}
