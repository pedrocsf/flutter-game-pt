part of 'leaderboard_bloc.dart';

sealed class LeaderboardEvent extends Equatable {
  const LeaderboardEvent();

  @override
  List<Object> get props => [];
}

class LeaderboardTop10Requested extends LeaderboardEvent {
  const LeaderboardTop10Requested({this.difficulty = GameDifficulty.medium});

  final GameDifficulty difficulty;

  @override
  List<Object> get props => [difficulty];
}
