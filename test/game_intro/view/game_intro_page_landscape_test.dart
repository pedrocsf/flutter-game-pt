import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/game_intro/game_intro.dart';
import 'package:moovz_dash/settings/settings.dart';

import '../../helpers/helpers.dart';

class _MockSettingsController extends Mock implements SettingsController {}

const _landscapeSizes = [Size(915, 412), Size(740, 360)];

void main() {
  group('GameIntroPage landscape', () {
    for (final size in _landscapeSizes) {
      testWidgets('renders without overflow at $size', (tester) async {
        tester.setViewSize(size: size);
        final settingsController = _MockSettingsController();
        when(() => settingsController.muted).thenReturn(ValueNotifier(true));

        await tester.pumpApp(
          const GameIntroPage(),
          settingsController: settingsController,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(DifficultySelector), findsOneWidget);
        expect(find.byType(HowToPlayButton), findsOneWidget);
      });
    }
  });
}
