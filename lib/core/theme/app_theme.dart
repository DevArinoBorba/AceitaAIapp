import 'package:flutter/material.dart';

import '../../domain/entities/verdict.dart';

/// Paleta "cockpit": fundo quase preto, verde de aprovação, âmbar de atenção,
/// vermelho de recusa. O app é dark-first (como o GigU) — tema claro fica
/// para depois, quando houver demanda real.
class AppColors {
  const AppColors._();

  static const bg = Color(0xFF080C11);
  static const surface = Color(0xFF11171F);
  static const surfaceAlt = Color(0xFF18202A);
  static const border = Color(0xFF222D3A);

  static const primary = Color(0xFF7BE04A);
  static const primaryInk = Color(0xFF08130A);

  static const good = Color(0xFF3DDC97);
  static const average = Color(0xFFFFB020);
  static const bad = Color(0xFFFF5A5F);

  static const text = Color(0xFFE9EFF5);
  static const muted = Color(0xFF8B9AAB);
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
    error: AppColors.bad,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
  );
}
