import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:moovz_dash/app_lifecycle/app_lifecycle.dart';
import 'package:moovz_dash/audio/audio.dart';
import 'package:moovz_dash/game_intro/game_intro.dart';
import 'package:moovz_dash/l10n/l10n.dart';
import 'package:moovz_dash/map_tester/map_tester.dart';
import 'package:moovz_dash/settings/settings.dart';
import 'package:moovz_dash/share/share.dart';

class App extends StatelessWidget {
  const App({
    required this.audioController,
    required this.settingsController,
    required this.shareController,
    required this.leaderboardRepository,
    this.isTesting = false,
    super.key,
  });

  final bool isTesting;
  final AudioController audioController;
  final SettingsController settingsController;
  final ShareController shareController;
  final LeaderboardRepository leaderboardRepository;

  @override
  Widget build(BuildContext context) {
    return AppLifecycleObserver(
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AudioController>(
            create: (context) {
              final lifecycleNotifier = context
                  .read<ValueNotifier<AppLifecycleState>>();
              return audioController
                ..attachLifecycleNotifier(lifecycleNotifier);
            },
            lazy: false,
          ),
          RepositoryProvider<SettingsController>.value(
            value: settingsController,
          ),
          RepositoryProvider<ShareController>.value(value: shareController),
          RepositoryProvider<LeaderboardRepository>.value(
            value: leaderboardRepository,
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
              primary: AppColors.primary,
            ),
            scaffoldBackgroundColor: AppColors.background,
            textTheme: AppTextStyles.textTheme,
          ),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale?.languageCode == 'en') {
              return const Locale('en');
            }
            return const Locale('pt');
          },
          home: isTesting ? const MapTesterView() : const GameIntroPage(),
        ),
      ),
    );
  }
}
