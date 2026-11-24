// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/leaderboard/bloc/leaderboard_bloc.dart';

class _MockLeaderboardRepository extends Mock
    implements LeaderboardRepository {}

class _FakeLeaderboardEntryData extends Fake implements LeaderboardEntryData {}

void main() {
  group('LeaderboardBloc', () {
    late LeaderboardRepository leaderboardRepository;
    late LeaderboardEntryData leaderboardEntryData;

    setUp(() {
      leaderboardRepository = _MockLeaderboardRepository();
      leaderboardEntryData = _FakeLeaderboardEntryData();
    });

    test(
      'default state is LeaderboardInitial',
      () => expect(
        LeaderboardBloc(leaderboardRepository: leaderboardRepository).state,
        isA<LeaderboardInitial>(),
      ),
    );

    blocTest<LeaderboardBloc, LeaderboardState>(
      'emits [LeaderboardLoading, LeaderboardLoaded] '
      'when LeaderboardTop10Requested is added and repository returns data',
      setUp: () {
        when(
          () => leaderboardRepository.fetchTop10Leaderboard(
            difficultyKey: any(named: 'difficultyKey'),
          ),
        ).thenAnswer((_) async => [leaderboardEntryData]);
      },
      build: () =>
          LeaderboardBloc(leaderboardRepository: leaderboardRepository),
      act: (bloc) => bloc.add(LeaderboardTop10Requested()),
      expect: () => [
        LeaderboardLoading(),
        LeaderboardLoaded(entries: [leaderboardEntryData]),
      ],
    );

    blocTest<LeaderboardBloc, LeaderboardState>(
      'fetches the leaderboard of the requested difficulty',
      setUp: () {
        when(
          () => leaderboardRepository.fetchTop10Leaderboard(
            difficultyKey: any(named: 'difficultyKey'),
          ),
        ).thenAnswer((_) async => [leaderboardEntryData]);
      },
      build: () =>
          LeaderboardBloc(leaderboardRepository: leaderboardRepository),
      act: (bloc) =>
          bloc.add(LeaderboardTop10Requested(difficulty: GameDifficulty.hard)),
      expect: () => [
        LeaderboardLoading(),
        LeaderboardLoaded(
          difficulty: GameDifficulty.hard,
          entries: [leaderboardEntryData],
        ),
      ],
      verify: (_) {
        verify(
          () => leaderboardRepository.fetchTop10Leaderboard(
            difficultyKey: 'hard',
          ),
        ).called(1);
      },
    );

    blocTest<LeaderboardBloc, LeaderboardState>(
      'emits [LeaderboardLoading, LeaderboardError] '
      'when LeaderboardTop10Requested is added and repository fails',
      setUp: () {
        when(
          () => leaderboardRepository.fetchTop10Leaderboard(
            difficultyKey: any(named: 'difficultyKey'),
          ),
        ).thenThrow(Exception());
      },
      build: () =>
          LeaderboardBloc(leaderboardRepository: leaderboardRepository),
      act: (bloc) => bloc.add(LeaderboardTop10Requested()),
      expect: () => [LeaderboardLoading(), LeaderboardError()],
    );
  });
}
