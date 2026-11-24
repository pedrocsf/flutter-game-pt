import 'package:app_ui/src/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// {@template game_button}
/// Common elevated button for the screens in the game.
/// {@endtemplate}
class GameElevatedButton extends StatelessWidget {
  /// {@macro game_button}
  GameElevatedButton({
    required String label,
    VoidCallback? onPressed,
    this.gradient,
    super.key,
  }) : _child = FilledButton(
         onPressed: onPressed,
         child: Text(label),
       );

  /// {@macro game_button}
  GameElevatedButton.icon({
    required String label,
    required Icon icon,
    VoidCallback? onPressed,
    this.gradient,
    super.key,
  }) : _child = FilledButton.icon(
         icon: icon,
         label: Text(label),
         onPressed: onPressed,
       );

  static const double _compactHeightThreshold = 500;
  static const double _regularVerticalPadding = 22;
  static const double _compactVerticalPadding = 12;

  final Widget _child;

  /// The gradient to use for the background.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verticalPadding =
        MediaQuery.sizeOf(context).height < _compactHeightThreshold
        ? _compactVerticalPadding
        : _regularVerticalPadding;
    return Container(
      width: 200,
      decoration: BoxDecoration(
        gradient:
            gradient ??
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.primaryGradient,
            ),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(94),
      ),
      child: Theme(
        data: theme.copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.onSurface,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(94),
              ),
              padding: EdgeInsets.symmetric(vertical: verticalPadding),
              textStyle: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        child: _child,
      ),
    );
  }
}
