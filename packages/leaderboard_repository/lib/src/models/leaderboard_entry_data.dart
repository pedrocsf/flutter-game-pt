import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'leaderboard_entry_data.g.dart';

/// {@template leaderboard_entry_data}
/// A model representing a leaderboard entry containing the player's nickname
/// and score.
///
/// Stored locally on the device as part of the leaderboard list.
///
/// Example:
/// ```json
/// {
///   "playerNickname" : "Dash",
///   "score" : 1500
/// }
/// ```
/// {@endtemplate}
@JsonSerializable()
class LeaderboardEntryData extends Equatable {
  /// {@macro leaderboard_entry_data}
  const LeaderboardEntryData({
    required this.playerNickname,
    required this.score,
  });

  /// Factory which converts a [Map] into a [LeaderboardEntryData].
  factory LeaderboardEntryData.fromJson(Map<String, dynamic> json) {
    return _$LeaderboardEntryDataFromJson(json);
  }

  /// Converts the [LeaderboardEntryData] to [Map].
  Map<String, dynamic> toJson() => _$LeaderboardEntryDataToJson(this);

  /// Player's chosen nickname for [LeaderboardEntryData].
  ///
  /// Example: 'Dash'.
  @JsonKey(name: 'playerNickname')
  final String playerNickname;

  /// Score for [LeaderboardEntryData].
  ///
  /// Example: 1500.
  @JsonKey(name: 'score')
  final int score;

  /// An empty [LeaderboardEntryData] object.
  static const empty = LeaderboardEntryData(score: 0, playerNickname: '');

  @override
  List<Object?> get props => [playerNickname, score];
}
