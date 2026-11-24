import 'package:app_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// {@template traslucent_background}
/// A traslucent background for the widgets.
/// {@endtemplate}
class TraslucentBackground extends StatelessWidget {
  /// {@macro traslucent_background}
  const TraslucentBackground({
    required this.child,
    required this.gradient,
    this.shape = BoxShape.circle,
    this.border,
    this.borderRadius,
    super.key,
  });

  /// The child widget on top of the background.
  final Widget child;

  /// The shape of the button.
  final BoxShape shape;

  /// The border of the button.
  final Border? border;

  /// The border radius of the button.
  final BorderRadius? borderRadius;

  /// The colors gradient to use for the button.
  final List<Color> gradient;

  static const _backgroundAlpha = 0.6;

  static const _gradientOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: shape,
              border: border,
              borderRadius: borderRadius,
              color: AppColors.background.withValues(alpha: _backgroundAlpha),
            ),
            child: Opacity(
              opacity: _gradientOpacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: shape,
                  borderRadius: borderRadius,
                  gradient: LinearGradient(colors: gradient),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
