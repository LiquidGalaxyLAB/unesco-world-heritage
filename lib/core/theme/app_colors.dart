import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color primary = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFF121212);
  static const Color primaryContainer = Color(0xFF4B4D60);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);

  //lg connected green
  static const Color secondary = Color(0xFF00C853);
  static const Color onSecondary = Color(0xFF000000);
  static const Color secondaryContainer = Color(0xFF003914);
  static const Color onSecondaryContainer = Color(0xFF69FF93);

  static const Color tertiary = Color(0xFFB6B6B6);
  static const Color onTertiary = Color(0xFF121212);
  static const Color tertiaryContainer = Color(0xFF2B2B2B);
  static const Color onTertiaryContainer = Color(0xFFE0E0E0);

  static const Color error = Color(0xFFFF4F3D);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFF321410);
  static const Color onErrorContainer = Color(0xFFFFB4AB);

  static const Color background = Color(0xFF121212);
  static const Color onBackground = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color onSurface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFF2B2B2B);
  static const Color onSurfaceVariant = Color(0xFFA8A8A8);

  static const Color surfaceContainerLowest = Color(0xFF0F0F0F);
  static const Color surfaceContainerLow = Color(0xFF121212);
  static const Color surfaceContainer = Color(0xFF151515);
  static const Color surfaceContainerHigh = Color(0xFF1E1E1E);
  static const Color surfaceContainerHighest = Color(0xFF242424);
  static const Color surfaceDim = Color(0xFF121212);
  static const Color surfaceBright = Color(0xFF303030);

  static const Color outline = Color(0xFF696773);
  static const Color outlineVariant = Color(0xFF45454A);

  static const Color inverseSurface = Color(0xFFE5E5E5);
  static const Color inverseOnSurface = Color(0xFF1E1E1E);
  static const Color inversePrimary = Color(0xFF2C1810);

  static const Color shadow = Color(0xFF000000);
  static const Color scrim = Color(0xFF000000);

  static const Color disabled = Color(0x61FFFFFF);
  static const Color onDisabled = Color(0x61FFFFFF);

  // Figma exact colors
  static const Color lgCardBorder = Color(0xFF8E6D6D);
  static const Color lgButton = Color(0xFF4B4D60);
  static const Color lgDisconnected = Color(0xFFFF4F3D);
}
