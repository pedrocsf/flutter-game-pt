import 'package:app_ui/app_ui.dart';
import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/gen/assets.gen.dart';
import 'package:moovz_dash/l10n/l10n.dart';
import 'package:moovz_dash/score/score.dart';
import 'package:moovz_dash/utils/utils.dart';

const double _horizontalPadding = 32;
const double _verticalPadding = 8;
const double _logoWidth = 160;
const double _gap = 12;

class GameOverPage extends StatelessWidget {
  const GameOverPage({super.key});

  static Page<void> page() {
    return const MaterialPage(child: GameOverPage());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    const titleColor = AppColors.onSurface;

    return PageWithBackground(
      background: const GameBackground(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Assets.images.gameOverBg.provider(),
            fit: BoxFit.cover,
            alignment: isDesktop
                ? const Alignment(0, -.5)
                : Alignment.topCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _horizontalPadding,
                    vertical: _verticalPadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MoovzLogo(width: _logoWidth),
                            const SizedBox(height: _gap),
                            Text(
                              l10n.gameOver,
                              style: textTheme.headlineMedium?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              l10n.betterLuckNextTime,
                              style: textTheme.bodyLarge?.copyWith(
                                color: titleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.totalScore,
                              style: textTheme.bodyLarge?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: _gap),
                            const _ScoreWidget(),
                            const SizedBox(height: _gap),
                            GameElevatedButton(
                              label: l10n.submitScore,
                              onPressed: () {
                                context.read<ScoreBloc>().add(
                                  const ScoreSubmitted(),
                                );
                              },
                            ),
                            const SizedBox(height: _gap),
                            GameElevatedButton.icon(
                              label: l10n.playAgain,
                              icon: const Icon(Icons.refresh, size: 16),
                              onPressed: context.flow<ScoreState>().complete,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.surface,
                                  AppColors.background,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreWidget extends StatelessWidget {
  const _ScoreWidget();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final score = context.select((ScoreBloc bloc) => bloc.score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surface, AppColors.background],
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Assets.images.trophy.image(width: 40, height: 40),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: textTheme.headlineMedium?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(text: '${formatScore(score)} '),
                TextSpan(text: l10n.pts, style: const TextStyle(fontSize: 24)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatScore(int score) {
    final formatter = NumberFormat('#,###');
    return formatter.format(score);
  }
}
