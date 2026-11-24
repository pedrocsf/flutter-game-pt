// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/l10n/l10n.dart';
import 'package:moovz_dash/leaderboard/leaderboard.dart';
import 'package:moovz_dash/score/score.dart';

import '../../helpers/helpers.dart';

class _MockLeaderboardBloc extends MockBloc<LeaderboardEvent, LeaderboardState>
    implements LeaderboardBloc {}

class _FakeLeaderboardEntryData extends Fake implements LeaderboardEntryData {
  @override
  String get playerNickname => 'DASH';

  @override
  int get score => 42000;
}

void _expectStatusAvatar(WidgetTester tester, AvatarAnimation animation) {
  final avatar = tester.widget<AvatarAnimationWidget>(
    find.byType(AvatarAnimationWidget),
  );
  expect(avatar.animation, equals(animation));
  expect(avatar.appearance, equals(const AvatarAppearance.standard()));
  expect(avatar.size, equals(64));
  expect(
    tester.getSize(find.byType(AvatarAnimationWidget)),
    equals(const Size.square(64)),
  );
}

extension on WidgetTester {
  AppLocalizations l10n<T extends Widget>() => element(find.byType(T)).l10n;
}

void main() {
  landscapeLeaderboardTests();

  group('LeaderboardPage', () {
    test('is routable', () {
      expect(LeaderboardPage.page(), isA<MaterialPage<void>>());
      expect(LeaderboardPage.route(), isA<PageRoute<void>>());
    });

    testWidgets('renders LeaderboardView', (tester) async {
      await tester.pumpApp(LeaderboardPage());
      expect(find.byType(LeaderboardView), findsOneWidget);
    });
  });

  group('LeaderboardView', () {
    late FlowController<ScoreState> controller;
    late LeaderboardBloc leaderboardBloc;

    setUp(() {
      controller = FakeFlowController<ScoreState>(ScoreState());
      leaderboardBloc = _MockLeaderboardBloc();

      when(() => leaderboardBloc.state).thenReturn(const LeaderboardInitial());
    });

    Widget buildSubject({LeaderboardStep step = LeaderboardStep.gameIntro}) {
      return FlowBuilder<ScoreState>(
        controller: controller,
        onGeneratePages: (_, __) => [
          MaterialPage(
            child: BlocProvider.value(
              value: leaderboardBloc,
              child: LeaderboardView(step: step),
            ),
          ),
        ],
      );
    }

    testWidgets('renders play again button when step is game score', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject(step: LeaderboardStep.gameScore));
      expect(
        find.text(tester.l10n<LeaderboardView>().playAgain),
        findsOneWidget,
      );
    });

    testWidgets('renders go back button when step is game intro', (
      tester,
    ) async {
      await tester.pumpApp(
        // ignore: avoid_redundant_argument_values
        buildSubject(step: LeaderboardStep.gameIntro),
      );
      expect(
        find.text(tester.l10n<LeaderboardView>().leaderboardPageGoBackButton),
        findsOneWidget,
      );
    });

    testWidgets('renders the three difficulty tabs', (tester) async {
      await tester.pumpApp(buildSubject());
      final l10n = tester.l10n<LeaderboardView>();
      expect(find.byType(Tab), findsNWidgets(3));
      expect(find.text(l10n.difficultyEasy), findsOneWidget);
      expect(find.text(l10n.difficultyMedium), findsOneWidget);
      expect(find.text(l10n.difficultyHard), findsOneWidget);
    });

    testWidgets('requests the difficulty of the tapped tab', (tester) async {
      await tester.pumpApp(buildSubject());
      await tester.tap(
        find.text(tester.l10n<LeaderboardView>().difficultyHard),
      );
      await tester.pumpAndSettle();
      verify(
        () => leaderboardBloc.add(
          LeaderboardTop10Requested(difficulty: GameDifficulty.hard),
        ),
      ).called(1);
    });

    testWidgets('renders loading widget', (tester) async {
      when(() => leaderboardBloc.state).thenReturn(LeaderboardLoading());
      await tester.pumpApp(buildSubject());
      expect(find.byType(LeaderboardLoadingWidget), findsOneWidget);
      _expectStatusAvatar(tester, AvatarAnimation.run);
    });

    testWidgets('renders error widget', (tester) async {
      when(() => leaderboardBloc.state).thenReturn(LeaderboardError());
      await tester.pumpApp(buildSubject());
      expect(find.byType(LeaderboardErrorWidget), findsOneWidget);
      _expectStatusAvatar(tester, AvatarAnimation.deathFaint);
      expect(
        find.text(
          tester.l10n<LeaderboardView>().leaderboardPageLeaderboardErrorText,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders leaderboard empty text when entries is empty', (
      tester,
    ) async {
      when(
        () => leaderboardBloc.state,
      ).thenReturn(LeaderboardLoaded(entries: const []));
      await tester.pumpApp(buildSubject());
      expect(
        find.text(
          tester.l10n<LeaderboardView>().leaderboardPageLeaderboardNoEntries,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders leaderboard list when entries exist', (tester) async {
      when(
        () => leaderboardBloc.state,
      ).thenReturn(LeaderboardLoaded(entries: [_FakeLeaderboardEntryData()]));
      await tester.pumpApp(buildSubject());
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}

void landscapeLeaderboardTests() {
  group('LeaderboardView landscape', () {
    for (final size in const [Size(915, 412), Size(740, 360)]) {
      testWidgets('renders without overflow at $size', (tester) async {
        tester.setViewSize(size: size);
        final leaderboardBloc = _MockLeaderboardBloc();
        when(() => leaderboardBloc.state).thenReturn(
          LeaderboardLoaded(
            entries: List.generate(10, (_) => _FakeLeaderboardEntryData()),
          ),
        );

        await tester.pumpApp(
          BlocProvider<LeaderboardBloc>.value(
            value: leaderboardBloc,
            child: LeaderboardView(step: LeaderboardStep.gameIntro),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(Tab), findsNWidgets(3));
      });
    }
  });
}
