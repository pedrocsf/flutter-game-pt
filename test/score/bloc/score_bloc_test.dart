import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/score/bloc/score_bloc.dart';

class _MockLeaderboardRepository extends Mock
    implements LeaderboardRepository {}

const _score = 1500;

void main() {
  group('ScoreBloc', () {
    late LeaderboardRepository leaderboardRepository;

    setUpAll(() {
      registerFallbackValue(LeaderboardEntryData.empty);
    });

    setUp(() {
      leaderboardRepository = _MockLeaderboardRepository();
      when(
        () => leaderboardRepository.addLeaderboardEntry(
          any(),
          difficultyKey: any(named: 'difficultyKey'),
        ),
      ).thenAnswer((_) async {});
    });

    ScoreBloc buildBloc() =>
        ScoreBloc(score: _score, leaderboardRepository: leaderboardRepository);

    test('default state has an empty nickname', () {
      expect(buildBloc().state, const ScoreState());
    });

    blocTest<ScoreBloc, ScoreState>(
      'emits inputNickname when ScoreSubmitted is added',
      build: buildBloc,
      act: (bloc) => bloc.add(const ScoreSubmitted()),
      expect: () => const [ScoreState(status: ScoreStatus.inputNickname)],
    );

    blocTest<ScoreBloc, ScoreState>(
      'keeps the nickname case as typed',
      build: buildBloc,
      act: (bloc) => bloc.add(const ScoreNicknameUpdated(nickname: 'Dash_1')),
      expect: () => const [ScoreState(nickname: 'Dash_1')],
    );

    blocTest<ScoreBloc, ScoreState>(
      'emits invalid when nickname is shorter than 3 characters',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const ScoreNicknameUpdated(nickname: 'ab'))
        ..add(const ScoreNicknameSubmitted()),
      expect: () => const [
        ScoreState(nickname: 'ab'),
        ScoreState(nickname: 'ab', nicknameStatus: NicknameFormStatus.invalid),
      ],
      verify: (_) {
        verifyNever(
          () => leaderboardRepository.addLeaderboardEntry(
            any(),
            difficultyKey: any(named: 'difficultyKey'),
          ),
        );
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'emits invalid when nickname is longer than 12 characters',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const ScoreNicknameUpdated(nickname: 'abcdefghijklm'))
        ..add(const ScoreNicknameSubmitted()),
      expect: () => const [
        ScoreState(nickname: 'abcdefghijklm'),
        ScoreState(
          nickname: 'abcdefghijklm',
          nicknameStatus: NicknameFormStatus.invalid,
        ),
      ],
    );

    blocTest<ScoreBloc, ScoreState>(
      'emits invalid when nickname contains a space or symbol',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const ScoreNicknameUpdated(nickname: 'da sh'))
        ..add(const ScoreNicknameSubmitted()),
      expect: () => const [
        ScoreState(nickname: 'da sh'),
        ScoreState(
          nickname: 'da sh',
          nicknameStatus: NicknameFormStatus.invalid,
        ),
      ],
    );

    blocTest<ScoreBloc, ScoreState>(
      'emits blacklisted when nickname matches a blocked word ignoring case',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const ScoreNicknameUpdated(nickname: 'FuK'))
        ..add(const ScoreNicknameSubmitted()),
      expect: () => const [
        ScoreState(nickname: 'FuK'),
        ScoreState(
          nickname: 'FuK',
          nicknameStatus: NicknameFormStatus.blacklisted,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => leaderboardRepository.addLeaderboardEntry(
            any(),
            difficultyKey: any(named: 'difficultyKey'),
          ),
        );
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'resets blacklisted status when nickname is updated',
      build: buildBloc,
      seed: () => const ScoreState(
        nickname: 'fuk',
        nicknameStatus: NicknameFormStatus.blacklisted,
      ),
      act: (bloc) => bloc.add(const ScoreNicknameUpdated(nickname: 'fukk')),
      expect: () => const [ScoreState(nickname: 'fukk')],
    );

    blocTest<ScoreBloc, ScoreState>(
      'emits blacklisted again when a blocked word is resubmitted',
      build: buildBloc,
      seed: () => const ScoreState(
        nickname: 'fuk',
        nicknameStatus: NicknameFormStatus.blacklisted,
      ),
      act: (bloc) => bloc
        ..add(const ScoreNicknameUpdated(nickname: 'FUK'))
        ..add(const ScoreNicknameSubmitted()),
      expect: () => const [
        ScoreState(nickname: 'FUK'),
        ScoreState(
          nickname: 'FUK',
          nicknameStatus: NicknameFormStatus.blacklisted,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => leaderboardRepository.addLeaderboardEntry(
            any(),
            difficultyKey: any(named: 'difficultyKey'),
          ),
        );
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'resets invalid status when nickname is updated to a valid value',
      build: buildBloc,
      seed: () => const ScoreState(
        nickname: 'ab',
        nicknameStatus: NicknameFormStatus.invalid,
      ),
      act: (bloc) => bloc.add(const ScoreNicknameUpdated(nickname: 'Dash_1')),
      expect: () => const [ScoreState(nickname: 'Dash_1')],
    );

    blocTest<ScoreBloc, ScoreState>(
      'sends the entry after an invalid submission once the nickname is valid',
      build: buildBloc,
      seed: () => const ScoreState(
        nickname: 'ab',
        nicknameStatus: NicknameFormStatus.invalid,
      ),
      act: (bloc) => bloc
        ..add(const ScoreNicknameUpdated(nickname: 'Dash_1'))
        ..add(const ScoreNicknameSubmitted()),
      expect: () => const [
        ScoreState(nickname: 'Dash_1'),
        ScoreState(
          nickname: 'Dash_1',
          nicknameStatus: NicknameFormStatus.loading,
        ),
        ScoreState(
          status: ScoreStatus.scoreOverview,
          nickname: 'Dash_1',
          nicknameStatus: NicknameFormStatus.loading,
        ),
      ],
      verify: (_) {
        verify(
          () => leaderboardRepository.addLeaderboardEntry(
            const LeaderboardEntryData(playerNickname: 'Dash_1', score: _score),
            difficultyKey: 'medium',
          ),
        ).called(1);
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'does not reintroduce invalid on update until the next submission',
      build: buildBloc,
      seed: () => const ScoreState(
        nickname: 'ab',
        nicknameStatus: NicknameFormStatus.invalid,
      ),
      act: (bloc) => bloc.add(const ScoreNicknameUpdated(nickname: 'a b')),
      expect: () => const [ScoreState(nickname: 'a b')],
    );

    blocTest<ScoreBloc, ScoreState>(
      'emits invalid again when the still-invalid nickname is submitted',
      build: buildBloc,
      seed: () => const ScoreState(
        nickname: 'ab',
        nicknameStatus: NicknameFormStatus.invalid,
      ),
      act: (bloc) => bloc
        ..add(const ScoreNicknameUpdated(nickname: 'a b'))
        ..add(const ScoreNicknameSubmitted()),
      expect: () => const [
        ScoreState(nickname: 'a b'),
        ScoreState(nickname: 'a b', nicknameStatus: NicknameFormStatus.invalid),
      ],
      verify: (_) {
        verifyNever(
          () => leaderboardRepository.addLeaderboardEntry(
            any(),
            difficultyKey: any(named: 'difficultyKey'),
          ),
        );
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'sends the entry and goes to scoreOverview when nickname is valid',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const ScoreNicknameUpdated(nickname: 'Dash_1'))
        ..add(const ScoreNicknameSubmitted()),
      expect: () => const [
        ScoreState(nickname: 'Dash_1'),
        ScoreState(
          nickname: 'Dash_1',
          nicknameStatus: NicknameFormStatus.loading,
        ),
        ScoreState(
          status: ScoreStatus.scoreOverview,
          nickname: 'Dash_1',
          nicknameStatus: NicknameFormStatus.loading,
        ),
      ],
      verify: (_) {
        verify(
          () => leaderboardRepository.addLeaderboardEntry(
            const LeaderboardEntryData(playerNickname: 'Dash_1', score: _score),
            difficultyKey: 'medium',
          ),
        ).called(1);
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'emits failure when the repository throws while adding the entry',
      setUp: () {
        when(
          () => leaderboardRepository.addLeaderboardEntry(
            any(),
            difficultyKey: any(named: 'difficultyKey'),
          ),
        ).thenAnswer(
          (_) async =>
              throw AddLeaderboardEntryException(Exception(), StackTrace.empty),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const ScoreNicknameUpdated(nickname: 'Dash_1'))
        ..add(const ScoreNicknameSubmitted()),
      expect: () => const [
        ScoreState(nickname: 'Dash_1'),
        ScoreState(
          nickname: 'Dash_1',
          nicknameStatus: NicknameFormStatus.loading,
        ),
        ScoreState(
          nickname: 'Dash_1',
          nicknameStatus: NicknameFormStatus.failure,
        ),
      ],
      errors: () => [isA<AddLeaderboardEntryException>()],
    );

    for (final nickname in ['abc', 'abcdefghijkl', 'A_1']) {
      blocTest<ScoreBloc, ScoreState>(
        'accepts "$nickname" as a valid nickname',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(ScoreNicknameUpdated(nickname: nickname))
          ..add(const ScoreNicknameSubmitted()),
        verify: (_) {
          verify(
            () => leaderboardRepository.addLeaderboardEntry(
              LeaderboardEntryData(playerNickname: nickname, score: _score),
              difficultyKey: 'medium',
            ),
          ).called(1);
        },
      );
    }
  });
}
