import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moovz_dash/audio/audio.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/game_intro/game_intro.dart';

class Game extends StatelessWidget {
  const Game({super.key, this.difficulty = GameDifficulty.medium});

  final GameDifficulty difficulty;

  static PageRoute<void> route({
    GameDifficulty difficulty = GameDifficulty.medium,
  }) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => Game(difficulty: difficulty),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GameBloc(),
      child: GameView(difficulty: difficulty),
    );
  }
}

class GameView extends StatefulWidget {
  const GameView({super.key, this.difficulty = GameDifficulty.medium});

  final GameDifficulty difficulty;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  static const _hudMargin = 12.0;
  static const _hudSpacing = 10.0;
  static const _popupTop = 84.0;

  MoovzDashGame? _game;

  MoovzDashGame _createGame() {
    return _game = MoovzDashGame(
      gameBloc: context.read<GameBloc>(),
      audioController: context.read<AudioController>(),
      difficulty: widget.difficulty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.topLeft,
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) => _game?.handlePointerDown(event),
            onPointerMove: (event) => _game?.handlePointerMove(event),
            onPointerUp: (event) => _game?.handlePointerUp(event),
            onPointerCancel: (event) => _game?.handlePointerCancel(event),
            child: GameWidget.controlled(
              loadingBuilder: (context) => const GameBackground(),
              backgroundBuilder: (context) => const GameBackground(),
              gameFactory: _createGame,
              overlayBuilderMap: {
                'tapToJump': (context, game) => const TapToJumpOverlay(),
              },
              initialActiveOverlays: const ['tapToJump'],
            ),
          ),
          const Positioned(
            top: _hudMargin,
            left: _hudMargin,
            child: SafeArea(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScoreLabel(),
                  SizedBox(width: _hudSpacing),
                  LivesLabel(),
                ],
              ),
            ),
          ),
          const Positioned(
            top: _popupTop,
            left: 0,
            right: 0,
            child: SafeArea(child: Center(child: SpecialItemPopup())),
          ),
          const Positioned(
            top: _hudMargin,
            right: _hudMargin,
            child: SafeArea(child: AudioButton()),
          ),
        ],
      ),
    );
  }
}
