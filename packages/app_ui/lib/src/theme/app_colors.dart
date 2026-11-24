import 'package:flutter/material.dart';

/// Color palette of the Moovz Dash game.
abstract final class AppColors {
  const AppColors._();

  /// Main brand color.
  static const Color primary = Color(0xFFF85F00);

  /// Lighter brand variant.
  static const Color primaryLight = Color(0xFFFF8C5A);

  /// Darker brand variant.
  static const Color primaryDark = Color(0xFFA53C00);

  /// Default screen background.
  static const Color background = Color(0xFF201A18);

  /// Default surface color for cards and containers.
  static const Color surface = Color(0xFF362F2C);

  /// Translucent background used behind dialogs.
  static const Color surfaceDialog = Color(0xE5201A18);

  /// Color of content drawn over surfaces.
  static const Color onSurface = Color(0xFFFFFFFF);

  /// Secondary content color drawn over surfaces.
  static const Color onSurfaceMuted = Color(0xFFB4A9A5);

  /// Subtle border color.
  static const Color border = Color(0x3DFFFFFF);

  /// Success state color.
  static const Color success = Color(0xFF6CE9A6);

  /// Error state color.
  static const Color error = Color(0xFFFFB4AB);

  /// Gradient colors used by primary highlights.
  static const List<Color> primaryGradient = [primaryLight, primary];
}
