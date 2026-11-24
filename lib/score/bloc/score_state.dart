part of 'score_bloc.dart';

enum ScoreStatus { gameOver, inputNickname, scoreOverview, leaderboard }

enum NicknameFormStatus {
  initial,
  loading,
  success,
  invalid,
  failure,
  blacklisted,
}

class ScoreState extends Equatable {
  const ScoreState({
    this.status = ScoreStatus.gameOver,
    this.nickname = '',
    this.nicknameStatus = NicknameFormStatus.initial,
    this.difficulty = GameDifficulty.medium,
  });

  final ScoreStatus status;
  final String nickname;
  final NicknameFormStatus nicknameStatus;
  final GameDifficulty difficulty;

  ScoreState copyWith({
    ScoreStatus? status,
    String? nickname,
    NicknameFormStatus? nicknameStatus,
  }) {
    return ScoreState(
      status: status ?? this.status,
      nickname: nickname ?? this.nickname,
      nicknameStatus: nicknameStatus ?? this.nicknameStatus,
      difficulty: difficulty,
    );
  }

  @override
  List<Object> get props => [status, nickname, nicknameStatus, difficulty];
}
