import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leaderboard_repository/leaderboard_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/app/app.dart';
import 'package:moovz_dash/audio/audio.dart';
import 'package:moovz_dash/game_intro/game_intro.dart';
import 'package:moovz_dash/settings/settings.dart';
import 'package:moovz_dash/share/share.dart';

class _MockAudioController extends Mock implements AudioController {}

class _MockSettingsController extends Mock implements SettingsController {}

class _MockShareController extends Mock implements ShareController {}

class _MockLeaderboardRepository extends Mock
    implements LeaderboardRepository {}

void main() {
  group('App', () {
    late AudioController audioController;
    late SettingsController settingsController;
    late ShareController shareController;
    late LeaderboardRepository leaderboardRepository;

    setUp(() {
      audioController = _MockAudioController();
      settingsController = _MockSettingsController();
      shareController = _MockShareController();
      leaderboardRepository = _MockLeaderboardRepository();

      when(() => settingsController.muted).thenReturn(ValueNotifier(true));
    });

    testWidgets('renders GameIntroPage', (tester) async {
      await tester.pumpWidget(
        App(
          audioController: audioController,
          settingsController: settingsController,
          shareController: shareController,
          leaderboardRepository: leaderboardRepository,
        ),
      );
      expect(find.byType(GameIntroPage), findsOneWidget);
    });

    group('locale resolution', () {
      Future<Locale> pumpAppWithDeviceLocales(
        WidgetTester tester,
        List<Locale> deviceLocales,
      ) async {
        tester.platformDispatcher.localesTestValue = deviceLocales;
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);

        await tester.pumpWidget(
          App(
            audioController: audioController,
            settingsController: settingsController,
            shareController: shareController,
            leaderboardRepository: leaderboardRepository,
          ),
        );

        return Localizations.localeOf(
          tester.element(find.byType(GameIntroPage)),
        );
      }

      testWidgets('uses en when the device locale is en', (tester) async {
        final locale = await pumpAppWithDeviceLocales(tester, const [
          Locale('en'),
        ]);

        expect(locale, const Locale('en'));
      });

      testWidgets('uses pt when the device locale is pt', (tester) async {
        final locale = await pumpAppWithDeviceLocales(tester, const [
          Locale('pt'),
        ]);

        expect(locale, const Locale('pt'));
      });

      testWidgets('falls back to pt for an unsupported device locale', (
        tester,
      ) async {
        final locale = await pumpAppWithDeviceLocales(tester, const [
          Locale('fr'),
        ]);

        expect(locale, const Locale('pt'));
      });

      testWidgets('falls back to pt when there is no device locale', (
        tester,
      ) async {
        final locale = await pumpAppWithDeviceLocales(tester, const []);

        expect(locale, const Locale('pt'));
      });
    });
  });
}
