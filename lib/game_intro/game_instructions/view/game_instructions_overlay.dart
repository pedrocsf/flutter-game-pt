import 'dart:ui' as ui;

import 'package:app_ui/app_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moovz_dash/game_intro/game_intro.dart';
import 'package:moovz_dash/gen/assets.gen.dart';
import 'package:moovz_dash/l10n/l10n.dart';
import 'package:moovz_dash/utils/utils.dart';

class GameInstruction extends Equatable {
  const GameInstruction({
    required this.title,
    required this.description,
    required this.assetPath,
  });

  final String title;
  final String description;
  final String assetPath;

  @override
  List<Object> get props => [title, description, assetPath];
}

class GameInstructionsOverlay extends StatelessWidget {
  const GameInstructionsOverlay({super.key});

  static PageRoute<void> route() {
    return HeroDialogRoute(
      builder: (_) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: const GameInstructionsOverlay(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GameInstructionsCubit(),
      child: const GameInstructionsOverlayView(),
    );
  }
}

const double _dialogMaxWidth = 640;
const double _pageHeight = 190;
const double _imageSize = 160;
const double _imageGap = 24;
const double _controlsGap = 8;

class GameInstructionsOverlayView extends StatefulWidget {
  const GameInstructionsOverlayView({super.key});

  @override
  State<GameInstructionsOverlayView> createState() =>
      _GameInstructionsOverlayViewState();
}

class _GameInstructionsOverlayViewState
    extends State<GameInstructionsOverlayView> {
  late final PageController pageController;

  List<GameInstruction> get instructions {
    final l10n = context.l10n;
    return [
      GameInstruction(
        title: l10n.gameInstructionsPageAutoRunTitle,
        description: l10n.gameInstructionsPageAutoRunDescription,
        assetPath: Assets.images.autoRunInstruction.path,
      ),
      if (isDesktop)
        GameInstruction(
          title: l10n.gameInstructionsPageTapToJumpTitle,
          description: l10n.gameInstructionsPageTapToJumpDescriptionDesktop,
          assetPath: Assets.images.tapToJumpSpacebar.path,
        )
      else
        GameInstruction(
          title: l10n.gameInstructionsPageTapToJumpTitle,
          description: l10n.gameInstructionsPageTapToJumpDescription,
          assetPath: Assets.images.tapToJumpInstruction.path,
        ),
      GameInstruction(
        title: l10n.gameInstructionsPageCollectEggsAcornsTitle,
        description: l10n.gameInstructionsPageCollectEggsAcornsDescription,
        assetPath: Assets.images.collectEggsAcornsInstruction.path,
      ),
      GameInstruction(
        title: l10n.gameInstructionsPagePowerfulWingsTitle,
        description: l10n.gameInstructionsPagePowerfulWingsDescription,
        assetPath: Assets.images.powerfulWingsInstruction.path,
      ),
      GameInstruction(
        title: l10n.gameInstructionsPageLevelGatesTitle,
        description: l10n.gameInstructionsPageLevelGatesDescription,
        assetPath: Assets.images.portalInstruction.path,
      ),
      GameInstruction(
        title: l10n.gameInstructionsPageAvoidBugsTitle,
        description: l10n.gameInstructionsPageAvoidBugsDescription,
        assetPath: Assets.images.avoidBugsInstruction.path,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      maxWidth: _dialogMaxWidth,
      border: Border.all(color: Colors.white24),
      backgroundColor: Colors.white24,
      imageProvider: Assets.images.instructionsBackground.provider(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _pageHeight,
            child: PageView.builder(
              controller: pageController,
              onPageChanged: context.read<GameInstructionsCubit>().updateStep,
              itemCount: instructions.length,
              itemBuilder: (context, index) {
                final instruction = instructions.elementAt(index);
                return _CardContent(
                  title: instruction.title,
                  description: instruction.description,
                  assetPath: instruction.assetPath,
                  pageController: pageController,
                );
              },
            ),
          ),
          const SizedBox(height: _controlsGap),
          GameInstructionNavigationControls(pageController: pageController),
        ],
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.title,
    required this.description,
    required this.assetPath,
    required this.pageController,
  });

  final String assetPath;
  final String title;
  final String description;
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _CardImage(assetPath: assetPath),
        const SizedBox(width: _imageGap),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _imageSize,
      height: _imageSize,
      child: TraslucentBackground(
        border: Border.all(color: Colors.white),
        gradient: const [
          AppColors.onSurfaceMuted,
          AppColors.surface,
          AppColors.onSurface,
          Colors.white38,
        ],
        child: Positioned.fill(
          child: Image.asset(
            assetPath,
            width: _imageSize - 30,
            height: _imageSize - 30,
          ),
        ),
      ),
    );
  }
}
