import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/score/bloc/score_bloc.dart';
import 'package:moovz_dash/score/routes/routes.dart';

class ScorePage extends StatelessWidget {
  const ScorePage({
    required this.score,
    this.difficulty = GameDifficulty.medium,
    super.key,
  });

  static PageRoute<void> route({
    required int score,
    GameDifficulty difficulty = GameDifficulty.medium,
  }) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) =>
          ScorePage(score: score, difficulty: difficulty),
    );
  }

  final int score;
  final GameDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ScoreBloc(
        score: score,
        difficulty: difficulty,
        leaderboardRepository: context.read<LeaderboardRepository>(),
      ),
      child: const ScoreView(),
    );
  }
}

class ScoreView extends StatelessWidget {
  const ScoreView({super.key});

  @override
  Widget build(BuildContext context) {
    return FlowBuilder<ScoreState>(
      state: context.select((ScoreBloc bloc) => bloc.state),
      onGeneratePages: onGenerateScorePages,
    );
  }
}
