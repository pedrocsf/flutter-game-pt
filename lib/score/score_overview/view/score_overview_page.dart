import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/gen/assets.gen.dart';
import 'package:moovz_dash/l10n/l10n.dart';
import 'package:moovz_dash/score/score.dart';
import 'package:moovz_dash/utils/utils.dart';

const double _outerPadding = 16;
const double _cardMaxWidth = 640;
const double _imageHeight = 160;
const double _gap = 12;

class ScoreOverviewPage extends StatelessWidget {
  const ScoreOverviewPage({super.key});

  static Page<void> page() {
    return const MaterialPage<void>(child: ScoreOverviewPage());
  }

  @override
  Widget build(BuildContext context) {
    return PageWithBackground(
      background: const GameBackground(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Assets.images.gameOverBg.provider(),
            fit: BoxFit.cover,
            colorFilter: const ColorFilter.mode(
              Colors.black38,
              BlendMode.darken,
            ),
            alignment: isDesktop
                ? const Alignment(0, .7)
                : Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(_outerPadding),
              child: AppCard(
                maxWidth: _cardMaxWidth,
                border: Border.all(color: Colors.white30),
                child: const _Content(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    const nicknameColor = AppColors.primaryLight;
    final nickname = context.select((ScoreBloc bloc) => bloc.state.nickname);

    return Row(
      children: [
        Assets.images.dashWins.image(height: _imageHeight),
        const SizedBox(width: _gap),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.shareYourScore, textAlign: TextAlign.center),
                  const SizedBox(height: _gap),
                  Text(
                    nickname,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: nicknameColor,
                    ),
                  ),
                  const SizedBox(height: _gap),
                  const _ScoreWidget(),
                  const SizedBox(height: _gap),
                  if (kIsWeb) const WebButtons() else const MobileButtons(),
                ],
              ),
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.onSurfaceMuted,
            AppColors.surface,
            AppColors.background,
          ],
          stops: [0.05, 0.5, 1],
        ),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Assets.images.trophy.image(width: 28, height: 28),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
              children: [
                TextSpan(text: '${formatScore(score)} '),
                TextSpan(text: l10n.pts),
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
