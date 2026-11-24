part of 'score_bloc.dart';

sealed class ScoreEvent extends Equatable {
  const ScoreEvent();

  @override
  List<Object> get props => [];
}

final class ScoreSubmitted extends ScoreEvent {
  const ScoreSubmitted();
}

final class ScoreNicknameUpdated extends ScoreEvent {
  const ScoreNicknameUpdated({required this.nickname});

  final String nickname;
}

final class ScoreNicknameSubmitted extends ScoreEvent {
  const ScoreNicknameSubmitted();
}

final class ScoreLeaderboardRequested extends ScoreEvent {
  const ScoreLeaderboardRequested();
}
