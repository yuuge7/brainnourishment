import 'package:flutter/material.dart' hide Ink;

import '../domain/game.dart';

abstract final class Palette {
  static const background = Color(0xFF090F21);
  static const surface = Color(0xFF131D33);
  static const border = Color(0xFF29354B);
  static const text = Color(0xFFF0F3FA);
  static const muted = Color(0xFFA6B3CA);
  static const mint = Color(0xFFB6F3CE);
  static const violet = Color(0xFFB7A4FF);
  static const cyan = Color(0xFF87DDF1);
  static const error = Color(0xFFFF8E9C);

  static Color accent(Exercise exercise) => switch (exercise) {
    Exercise.focus => violet,
    Exercise.logic => cyan,
    Exercise.memory => mint,
  };

  static IconData icon(Exercise exercise) => switch (exercise) {
    Exercise.focus => Icons.filter_center_focus_rounded,
    Exercise.logic => Icons.functions_rounded,
    Exercise.memory => Icons.grid_view_rounded,
  };

  static Color ink(Ink ink) => switch (ink) {
    Ink.red => const Color(0xFFFF7B8F),
    Ink.blue => const Color(0xFF80B6FF),
    Ink.green => const Color(0xFF8EE3B0),
    Ink.yellow => const Color(0xFFFFDB7A),
  };
}

TextStyle displayStyle(double size, {Color color = Palette.text}) => TextStyle(
  fontFamily: 'SpaceGrotesk',
  fontSize: size,
  fontWeight: FontWeight.w600,
  color: color,
  height: 1.12,
  letterSpacing: -1.3,
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.mint,
    brightness: Brightness.dark,
    surface: Palette.surface,
    primary: Palette.mint,
    onPrimary: Palette.background,
    error: Palette.error,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.background,
    fontFamily: 'Manrope',
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'Manrope',
      bodyColor: Palette.text,
      displayColor: Palette.text,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        foregroundColor: Palette.text,
        side: const BorderSide(color: Palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: Palette.muted,
        minimumSize: const Size(48, 48),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
