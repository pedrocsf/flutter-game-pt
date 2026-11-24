import 'package:app_ui/app_ui.dart';
import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/gen/assets.gen.dart';
import 'package:moovz_dash/l10n/l10n.dart';
import 'package:moovz_dash/leaderboard/bloc/leaderboard_bloc.dart';
import 'package:moovz_dash/score/score.dart';

const _statusAvatarSize = 64.0;
const _pagePadding = 12.0;
const _gap = 8.0;
const _logoWidth = 120.0;

enum LeaderboardStep { gameIntro, gameScore }

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({
    this.step = LeaderboardStep.gameIntro,
    this.initialDifficulty = GameDifficulty.medium,
    super.key,
  });

  static Page<void> page({
    LeaderboardStep step = LeaderboardStep.gameScore,
    GameDifficulty initialDifficulty = GameDifficulty.medium,
  }) {
    return MaterialPage(
      child: LeaderboardPage(step: step, initialDifficulty: initialDifficulty),
    );
  }

  static PageRoute<void> route({
    LeaderboardStep step = LeaderboardStep.gameIntro,
    GameDifficulty initialDifficulty = GameDifficulty.medium,
  }) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) =>
          LeaderboardPage(step: step, initialDifficulty: initialDifficulty),
    );
  }

  final LeaderboardStep step;
  final GameDifficulty initialDifficulty;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      )..add(LeaderboardTop10Requested(difficulty: initialDifficulty)),
      child: LeaderboardView(step: step, initialDifficulty: initialDifficulty),
    );
  }
}

class LeaderboardView extends StatefulWidget {
  const LeaderboardView({
    required this.step,
    this.initialDifficulty = GameDifficulty.medium,
    super.key,
  });

  final LeaderboardStep step;
  final GameDifficulty initialDifficulty;

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: GameDifficulty.values.length,
      vsync: this,
      initialIndex: widget.initialDifficulty.index,
    )..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    context.read<LeaderboardBloc>().add(
      LeaderboardTop10Requested(
        difficulty: GameDifficulty.values[_tabController.index],
      ),
    );
  }

  String _difficultyLabel(AppLocalizations l10n, GameDifficulty difficulty) {
    return switch (difficulty) {
      GameDifficulty.easy => l10n.difficultyEasy,
      GameDifficulty.medium => l10n.difficultyMedium,
      GameDifficulty.hard => l10n.difficultyHard,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final step = widget.step;
    return PageWithBackground(
      background: const GameBackground(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Assets.images.leaderboardBg.provider(),
            fit: BoxFit.fill,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: _pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const MoovzLogo(width: _logoWidth),
                    const SizedBox(width: _pagePadding),
                    SizedBox(
                      width: Leaderboard.width,
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.primary,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.onSurfaceMuted,
                        dividerColor: Colors.transparent,
                        tabs: [
                          for (final difficulty in GameDifficulty.values)
                            Tab(text: _difficultyLabel(l10n, difficulty)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: _gap),
                const Expanded(child: Center(child: Leaderboard())),
                const SizedBox(height: _gap),
                Align(
                  child: switch (step) {
                    LeaderboardStep.gameIntro => GameElevatedButton(
                      label: l10n.leaderboardPageGoBackButton,
                      onPressed: Navigator.of(context).pop,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.surface, AppColors.background],
                      ),
                    ),
                    LeaderboardStep.gameScore => GameElevatedButton.icon(
                      label: l10n.playAgain,
                      icon: const Icon(Icons.refresh, size: 16),
                      onPressed: context.flow<ScoreState>().complete,
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Leaderboard extends StatelessWidget {
  const Leaderboard({super.key});

  static const width = 460.0;
  static const fadeHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.background],
        ),
      ),
      child: BlocBuilder<LeaderboardBloc, LeaderboardState>(
        builder: (context, state) => switch (state) {
          LeaderboardInitial() => const SizedBox.shrink(),
          LeaderboardLoading() => const Center(
            child: LeaderboardLoadingWidget(),
          ),
          LeaderboardError() => const Center(child: LeaderboardErrorWidget()),
          LeaderboardLoaded(entries: final entries) => LeaderboardContent(
            entries: entries,
          ),
        },
      ),
    );
  }
}

@visibleForTesting
class LeaderboardErrorWidget extends StatelessWidget {
  const LeaderboardErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AvatarAnimationWidget(
          animation: AvatarAnimation.deathFaint,
          size: _statusAvatarSize,
        ),
        const SizedBox(height: 24),
        Text(context.l10n.leaderboardPageLeaderboardErrorText),
      ],
    );
  }
}

@visibleForTesting
class LeaderboardLoadingWidget extends StatelessWidget {
  const LeaderboardLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const AvatarAnimationWidget(
      animation: AvatarAnimation.run,
      size: _statusAvatarSize,
    );
  }
}

@visibleForTesting
class LeaderboardContent extends StatelessWidget {
  const LeaderboardContent({required this.entries, super.key});

  final List<LeaderboardEntryData> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                l10n.leaderboardPageLeaderboardHeadline,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(l10n.leaderboardPageLeaderboardNoEntries),
                  ),
                )
              else
                Expanded(child: _LeaderboardEntries(entries: entries)),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            width: Leaderboard.width,
            height: Leaderboard.fadeHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.8],
                colors: [Colors.transparent, AppColors.background],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardEntries extends StatelessWidget {
  const _LeaderboardEntries({required this.entries});

  final List<LeaderboardEntryData> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return ListView.separated(
      padding: EdgeInsets.zero,
      separatorBuilder: (context, index) =>
          const Divider(color: AppColors.border),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries.elementAt(index);
        return ListTile(
          dense: true,
          minVerticalPadding: 0,
          contentPadding: EdgeInsets.zero,
          leading: Text('#${index + 1}'),
          title: Text(entry.playerNickname),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ([0, 1, 2].contains(index)) ...[
                FaIcon(
                  FontAwesomeIcons.trophy,
                  size: 20,
                  color: switch (index) {
                    0 => const Color(0xFFD4AF37),
                    1 => const Color(0xFFC0C0C0),
                    _ => const Color(0xFFCD7F32),
                  },
                ),
                const SizedBox(width: 10),
              ],
              Text(l10n.gameScoreLabel(entry.score)),
            ],
          ),
          titleTextStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          leadingAndTrailingTextStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }
}
