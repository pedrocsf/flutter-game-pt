import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moovz_dash/game_intro/game_instructions/game_instructions.dart';

class GameInstructionNavigationControls extends StatelessWidget {
  const GameInstructionNavigationControls({
    required this.pageController,
    super.key,
  });

  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final currentStep = context.select(
      (GameInstructionsCubit cubit) => cubit.state.currentStep,
    );
    final isFirstStep = currentStep == GameInstructionsStep.values.first;
    final isLastStep = currentStep == GameInstructionsStep.values.last;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final step in GameInstructionsStep.values)
              _PageIndicator(step: step),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: isFirstStep ? 0.4 : 1,
              child: GameIconButton(
                icon: Icons.arrow_back,
                onPressed: isFirstStep
                    ? null
                    : () => pageController.previousPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeIn,
                      ),
              ),
            ),
            const SizedBox(width: 24),
            GameIconButton(
              icon: isLastStep ? Icons.check : Icons.arrow_forward,
              onPressed: isLastStep
                  ? Navigator.of(context).pop
                  : () => pageController.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeIn,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.step});

  static const inactiveGradient = [
    AppColors.onSurfaceMuted,
    AppColors.onSurface,
  ];

  static const activeGradient = AppColors.primaryGradient;

  final GameInstructionsStep step;

  @override
  Widget build(BuildContext context) {
    final currentStep = context.select(
      (GameInstructionsCubit cubit) => cubit.state.currentStep,
    );
    return Container(
      width: step == currentStep ? 24 : 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: step == currentStep ? BoxShape.rectangle : BoxShape.circle,
        border: Border.all(color: Colors.white),
        borderRadius: step == currentStep ? BorderRadius.circular(10) : null,
        gradient: LinearGradient(
          colors: step == currentStep ? activeGradient : inactiveGradient,
        ),
      ),
    );
  }
}
