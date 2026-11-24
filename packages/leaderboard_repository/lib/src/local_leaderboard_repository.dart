import 'dart:convert';

import 'package:leaderboard_repository/src/leaderboard_repository.dart';
import 'package:leaderboard_repository/src/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// {@template local_leaderboard_repository}
/// Repository which stores the Moovz Dash leaderboard on the device using
/// `shared_preferences`.
/// {@endtemplate}
class LocalLeaderboardRepository implements LeaderboardRepository {
  /// {@macro local_leaderboard_repository}
  const LocalLeaderboardRepository(SharedPreferences preferences)
    : _preferences = preferences;

  final SharedPreferences _preferences;

  static const _leaderboardLimit = 10;
  static const _legacyStorageKey = 'moovz_dash_leaderboard';
  static const _legacyDifficultyKey = 'medium';

  String _storageKey(String difficultyKey) =>
      '${_legacyStorageKey}_$difficultyKey';

  @override
  Future<List<LeaderboardEntryData>> fetchTop10Leaderboard({
    required String difficultyKey,
  }) async {
    return _readLeaderboard(difficultyKey);
  }

  @override
  Future<void> addLeaderboardEntry(
    LeaderboardEntryData entry, {
    required String difficultyKey,
  }) async {
    final leaderboard = _readLeaderboard(difficultyKey);
    final updatedLeaderboard = _insertSortedByScore(leaderboard, entry);
    await _saveLeaderboard(updatedLeaderboard, difficultyKey);
  }

  List<LeaderboardEntryData> _readLeaderboard(String difficultyKey) {
    final storedValue = _readStoredValue(difficultyKey);
    return _decodeLeaderboard(storedValue);
  }

  String? _readStoredValue(String difficultyKey) {
    try {
      final storedValue = _preferences.getString(_storageKey(difficultyKey));
      if (storedValue != null || difficultyKey != _legacyDifficultyKey) {
        return storedValue;
      }
      final legacyValue = _preferences.getString(_legacyStorageKey);
      if (legacyValue != null) {
        _preferences.setString(_storageKey(difficultyKey), legacyValue);
      }
      return legacyValue;
    } catch (error, stackTrace) {
      throw FetchTop10LeaderboardException(error, stackTrace);
    }
  }

  List<LeaderboardEntryData> _decodeLeaderboard(String? storedValue) {
    if (storedValue == null) {
      return [];
    }
    try {
      final decodedItems = jsonDecode(storedValue) as List<dynamic>;
      return decodedItems
          .map(
            (item) =>
                LeaderboardEntryData.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (error, stackTrace) {
      throw LeaderboardDeserializationException(error, stackTrace);
    }
  }

  List<LeaderboardEntryData> _insertSortedByScore(
    List<LeaderboardEntryData> leaderboard,
    LeaderboardEntryData entry,
  ) {
    final firstLowerScoreIndex = leaderboard.indexWhere(
      (existingEntry) => existingEntry.score < entry.score,
    );
    final insertionIndex = firstLowerScoreIndex == -1
        ? leaderboard.length
        : firstLowerScoreIndex;
    final updatedLeaderboard = [...leaderboard]..insert(insertionIndex, entry);
    return updatedLeaderboard.take(_leaderboardLimit).toList();
  }

  Future<void> _saveLeaderboard(
    List<LeaderboardEntryData> leaderboard,
    String difficultyKey,
  ) async {
    final storageKey = _storageKey(difficultyKey);
    final encodedLeaderboard = jsonEncode(
      leaderboard.map((entry) => entry.toJson()).toList(),
    );
    final bool wasSaved;
    try {
      wasSaved = await _preferences.setString(storageKey, encodedLeaderboard);
    } catch (error, stackTrace) {
      throw AddLeaderboardEntryException(error, stackTrace);
    }
    if (!wasSaved) {
      throw AddLeaderboardEntryException(
        StateError('Failed to persist leaderboard under $storageKey.'),
        StackTrace.current,
      );
    }
  }
}
