import 'package:app_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// {@template app_card}
/// An app themed card.
/// {@endtemplate}
class AppCard extends StatelessWidget {
  /// {@macro app_card}
  const AppCard({
    required this.child,
    this.backgroundColor = AppColors.surfaceDialog,
    this.gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.surface,
        AppColors.surfaceDialog,
        AppColors.background,
      ],
      stops: [0.05, 0.5, 1],
    ),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.border = const Border.fromBorderSide(
      BorderSide(color: AppColors.border),
    ),
    this.imageProvider,
    this.maxWidth = defaultMaxWidth,
    super.key,
  });

  /// The default maximum width of the card.
  static const double defaultMaxWidth = 328;

  /// The maximum width of the card.
  final double maxWidth;

  /// The content of the card.
  final Widget child;

  /// The background color of the card. Shown behind the [gradient].
  final Color? backgroundColor;

  /// The gradient of the card. Shown on top of the [backgroundColor].
  final LinearGradient? gradient;

  /// The border radius of the card.
  final BorderRadius? borderRadius;

  /// The border of the card.
  final BoxBorder? border;

  /// The background image of the card. Setting the image makes the [gradient]
  /// and [backgroundColor] invisible. Also removes the border.
  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    final showImage = imageProvider != null;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 624),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: showImage ? null : border,
        color: showImage ? null : backgroundColor,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: showImage ? null : gradient,
          image: showImage
              ? DecorationImage(
                  image: imageProvider!,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}
