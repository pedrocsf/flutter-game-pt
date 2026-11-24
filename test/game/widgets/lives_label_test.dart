import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/game/game.dart';

import '../../helpers/helpers.dart';

class _MockGameBloc extends MockBloc<GameEvent, GameState>
    implements GameBloc {}

void main() {
  group('LivesLabel', () {
    late GameBloc gameBloc;

    setUp(() => gameBloc = _MockGameBloc());

    Future<void> pumpLabel(WidgetTester tester) {
      return tester.pumpApp(
        BlocProvider.value(value: gameBloc, child: const LivesLabel()),
      );
    }

    int filledHearts(WidgetTester tester) {
      return find.byIcon(Icons.favorite).evaluate().length;
    }

    int emptyHearts(WidgetTester tester) {
      return find.byIcon(Icons.favorite_border).evaluate().length;
    }

    testWidgets('shows initial lives as filled hearts only', (tester) async {
      when(() => gameBloc.state).thenReturn(const GameState.initial());

      await pumpLabel(tester);

      expect(filledHearts(tester), GameState.initialLives);
      expect(emptyHearts(tester), isZero);
    });

    testWidgets('shows lost lives as empty hearts', (tester) async {
      when(
        () => gameBloc.state,
      ).thenReturn(const GameState.initial().copyWith(lives: 1));

      await pumpLabel(tester);

      expect(filledHearts(tester), 1);
      expect(emptyHearts(tester), GameState.initialLives - 1);
    });

    testWidgets('shows only empty hearts without lives', (tester) async {
      when(
        () => gameBloc.state,
      ).thenReturn(const GameState.initial().copyWith(lives: 0));

      await pumpLabel(tester);

      expect(filledHearts(tester), isZero);
      expect(emptyHearts(tester), GameState.initialLives);
    });

    testWidgets('shows only filled hearts at max lives', (tester) async {
      when(() => gameBloc.state).thenReturn(
        const GameState.initial().copyWith(lives: GameState.maxLives),
      );

      await pumpLabel(tester);

      expect(filledHearts(tester), GameState.maxLives);
      expect(emptyHearts(tester), isZero);
    });

    testWidgets('updates the hearts and pulses when the lives change', (
      tester,
    ) async {
      const initial = GameState.initial();
      whenListen(
        gameBloc,
        Stream.value(initial.copyWith(lives: 2)),
        initialState: initial,
      );

      await pumpLabel(tester);
      expect(filledHearts(tester), 3);

      await tester.pump();
      await tester.pump(LivesLabel.pulseDuration ~/ 2);

      final scale = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(LivesLabel),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scale.scale.value, greaterThan(1));

      await tester.pumpAndSettle();
      expect(filledHearts(tester), 2);
      expect(scale.scale.value, closeTo(1, .001));
    });
  });
}
