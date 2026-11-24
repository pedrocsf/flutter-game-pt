import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/game_intro/game_intro.dart';

import '../../helpers/helpers.dart';

void main() {
  group('DifficultySelector', () {
    testWidgets('changes selection on tap', (tester) async {
      var selected = GameDifficulty.medium;
      await tester.pumpApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DifficultySelector(
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      );

      expect(find.text('Easy'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);

      await tester.tap(find.text('Hard'));
      await tester.pump();

      expect(selected, GameDifficulty.hard);
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('difficulty_hard')),
      );
      expect(chip.selected, isTrue);
    });
  });
}
