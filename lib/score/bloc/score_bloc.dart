import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/score/input_nickname/nickname_rules.dart';

part 'score_event.dart';
part 'score_state.dart';

class ScoreBloc extends Bloc<ScoreEvent, ScoreState> {
  ScoreBloc({
    required this.score,
    required LeaderboardRepository leaderboardRepository,
    this.difficulty = GameDifficulty.medium,
  }) : _leaderboardRepository = leaderboardRepository,
       super(ScoreState(difficulty: difficulty)) {
    on<ScoreSubmitted>(_onScoreSubmitted);
    on<ScoreNicknameUpdated>(_onScoreNicknameUpdated);
    on<ScoreNicknameSubmitted>(_onScoreNicknameSubmitted);
    on<ScoreLeaderboardRequested>(_onScoreLeaderboardRequested);
  }

  final int score;
  final GameDifficulty difficulty;
  final LeaderboardRepository _leaderboardRepository;

  void _onScoreSubmitted(ScoreSubmitted event, Emitter<ScoreState> emit) {
    emit(state.copyWith(status: ScoreStatus.inputNickname));
  }

  void _onScoreNicknameUpdated(
    ScoreNicknameUpdated event,
    Emitter<ScoreState> emit,
  ) {
    final nicknameStatus =
        (state.nicknameStatus == NicknameFormStatus.blacklisted ||
            state.nicknameStatus == NicknameFormStatus.invalid)
        ? NicknameFormStatus.initial
        : state.nicknameStatus;
    emit(
      state.copyWith(nickname: event.nickname, nicknameStatus: nicknameStatus),
    );
  }

  Future<void> _onScoreNicknameSubmitted(
    ScoreNicknameSubmitted event,
    Emitter<ScoreState> emit,
  ) async {
    if (!_hasValidNickname()) {
      emit(state.copyWith(nicknameStatus: NicknameFormStatus.invalid));
    } else if (_isNicknameBlacklisted()) {
      emit(state.copyWith(nicknameStatus: NicknameFormStatus.blacklisted));
    } else {
      emit(state.copyWith(nicknameStatus: NicknameFormStatus.loading));
      try {
        await _leaderboardRepository.addLeaderboardEntry(
          LeaderboardEntryData(playerNickname: state.nickname, score: score),
          difficultyKey: difficulty.storageKey,
        );

        emit(state.copyWith(status: ScoreStatus.scoreOverview));
      } catch (e, s) {
        addError(e, s);
        emit(state.copyWith(nicknameStatus: NicknameFormStatus.failure));
      }
    }
  }

  bool _hasValidNickname() {
    return nicknameRegex.hasMatch(state.nickname);
  }

  bool _isNicknameBlacklisted() {
    return _blacklist.contains(state.nickname.toLowerCase());
  }

  void _onScoreLeaderboardRequested(
    ScoreLeaderboardRequested event,
    Emitter<ScoreState> emit,
  ) {
    emit(state.copyWith(status: ScoreStatus.leaderboard));
  }
}

const _blacklist = [
  'fuk',
  'fuc',
  'cok',
  'dik',
  'kkk',
  'sht',
  'cnt',
  'ass',
  'cum',
  'fag',
  'gay',
  'god',
  'jew',
  'sex',
  'tit',
  'wtf',
];
