import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryPurple = Color(0xFF6A5ACD); // Slate Blue
  static const Color secondaryPurple = Color(0xFF9370DB); // Medium Purple
  static const Color accentPink = Color(0xFFDA70D6); // Orchid
  static const Color accentBlue = Color(0xFF483D8B); // Dark Slate Blue
  static const Color neutralGray = Color(0xFFCCCCCC); // Light Gray
  static const Color contrastWhite = Color(0xFFFFFFFF); // White
}

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

class PastelNight extends ColorPalette {
  @override
  final String name = 'Pastel Night';
  @override
  final Color primary = const Color(0xFF504E70);
  @override
  final Color secondary = const Color(0xFF2E2C3A);
  @override
  final Color accent = const Color(0xFFB89BCA);
  @override
  final Color textPrimary = const Color(0xFFFFFFFF);
  @override
  final Color textSecondary = const Color(0xFFD3D3D3);
  @override
  final Color background = const Color(0xFF2B2B2B);
  @override
  final Color error = const Color(0xFFD291BC);
}

class CoolTwilight extends ColorPalette {
  @override
  final String name = 'Cool Twilight';
  @override
  final Color primary = const Color(0xFF7A6F9B);
  @override
  final Color secondary = const Color(0xFF474359);
  @override
  final Color accent = const Color(0xFF9D92C4);
  @override
  final Color textPrimary = const Color(0xFFF4F4F4);
  @override
  final Color textSecondary = const Color(0xFFCCCCCC);
  @override
  final Color background = const Color(0xFF2B2B2B);
  @override
  final Color error = const Color(0xFFD291BC);
}
