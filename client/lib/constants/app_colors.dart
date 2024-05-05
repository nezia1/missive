import 'package:flutter/material.dart';

/// An abstract class that defines the color palette for the app. Used in main.dart to build the application theme.
abstract class ColorPalette {
  String get name;
  Color get primary;
  Color get secondary;
  Color get accent;
  Color get textPrimary;
  Color get textSecondary;
  Color get background;
  Color get error;
}

/// Missive's main color palette. A dark theme with purple and grey colors that's easy on the eyes.
class PurpleDream extends ColorPalette {
  @override
  final String name = 'Purple Dream';
  @override
  final Color primary = const Color(0xFF625D92);
  @override
  final Color secondary = const Color(0xFF353446);
  @override
  final Color accent = const Color(0xFF957DAD);
  @override
  final Color textPrimary = const Color(0xFFEDEDED);
  @override
  final Color textSecondary = const Color(0xFFC4C4C4);
  @override
  final Color background = const Color(0xFF2B2B2B);
  @override
  final Color error = const Color(0xFFD291BC);
}
