import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moovz_dash/game/bloc/game_bloc.dart';
import 'package:moovz_dash/l10n/l10n.dart';

class LivesLabel extends StatefulWidget {
  const LivesLabel({super.key});

  static const pulseDuration = Duration(milliseconds: 350);
  static const pulseScale = 1.25;
  static const heartSize = 28.0;
  static const heartSpacing = 2.0;
  static const contentHeight = 40.0;
  static const emptyHeartAlpha = 0.35;
  static const filledHeartColor = Color(0xFFFF3B3B);

  @override
  State<LivesLabel> createState() => _LivesLabelState();
}

class _LivesLabelState extends State<LivesLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: LivesLabel.pulseDuration,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: LivesLabel.pulseScale,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: LivesLabel.pulseScale,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 1,
    ),
  ]).animate(_pulseController);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lives = context.select((GameBloc bloc) => bloc.state.lives);

    return BlocListener<GameBloc, GameState>(
      listenWhen: (previous, current) => previous.lives != current.lives,
      listener: (context, state) => _pulseController.forward(from: 0),
      child: Semantics(
        label: context.l10n.gameLivesLabel(lives),
        child: TraslucentBackground(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white),
          gradient: const [AppColors.surface, AppColors.background],
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              height: LivesLabel.contentHeight,
              child: ScaleTransition(
                scale: _scale,
                child: _HeartsRow(lives: lives),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartsRow extends StatelessWidget {
  const _HeartsRow({required this.lives});

  final int lives;

  @override
  Widget build(BuildContext context) {
    final heartSlots = math.max(GameState.initialLives, lives);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < heartSlots; index++)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LivesLabel.heartSpacing,
            ),
            child: _Heart(isFilled: index < lives),
          ),
      ],
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({required this.isFilled});

  final bool isFilled;

  @override
  Widget build(BuildContext context) {
    return Icon(
      isFilled ? Icons.favorite : Icons.favorite_border,
      size: LivesLabel.heartSize,
      color: isFilled
          ? LivesLabel.filledHeartColor
          : Colors.white.withValues(alpha: LivesLabel.emptyHeartAlpha),
    );
  }
}
