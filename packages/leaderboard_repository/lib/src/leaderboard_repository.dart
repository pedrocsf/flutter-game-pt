import 'package:leaderboard_repository/src/models/models.dart';

/// {@template leaderboard_repository}
/// Contract to access the Moovz Dash leaderboard.
/// {@endtemplate}
abstract interface class LeaderboardRepository {
  /// Acquires the top 10 entries of [difficultyKey], by score descending.
  Future<List<LeaderboardEntryData>> fetchTop10Leaderboard({
    required String difficultyKey,
  });

  /// Adds the player's [entry] to the leaderboard if it is within the top 10.
  Future<void> addLeaderboardEntry(
    LeaderboardEntryData entry, {
    required String difficultyKey,
  });
}
