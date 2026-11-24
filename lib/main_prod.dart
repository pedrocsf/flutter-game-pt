import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:moovz_dash/app/app.dart';
import 'package:moovz_dash/audio/audio.dart';
import 'package:moovz_dash/bootstrap.dart';
import 'package:moovz_dash/settings/persistence/persistence.dart';
import 'package:moovz_dash/settings/settings.dart';
import 'package:moovz_dash/share/share.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsController(
    persistence: LocalStorageSettingsPersistence(),
  );

  final audio = AudioController()..attachSettings(settings);

  await audio.initialize();

  final share = ShareController(gameUrl: 'https://superdash.flutter.dev/');

  final preferences = await SharedPreferences.getInstance();
  final LeaderboardRepository leaderboardRepository =
      LocalLeaderboardRepository(preferences);

  unawaited(
    bootstrap(
      () => App(
        audioController: audio,
        settingsController: settings,
        shareController: share,
        leaderboardRepository: leaderboardRepository,
      ),
    ),
  );
}
