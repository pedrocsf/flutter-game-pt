// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leaderboard_entry_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LeaderboardEntryData _$LeaderboardEntryDataFromJson(
  Map<String, dynamic> json,
) => LeaderboardEntryData(
  playerNickname: json['playerNickname'] as String,
  score: (json['score'] as num).toInt(),
);

Map<String, dynamic> _$LeaderboardEntryDataToJson(
  LeaderboardEntryData instance,
) => <String, dynamic>{
  'playerNickname': instance.playerNickname,
  'score': instance.score,
};
