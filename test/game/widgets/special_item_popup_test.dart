import 'dart:async';

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
  group('SpecialItemPopup', () {
    late GameBloc gameBloc;

    setUp(() {
      gameBloc = _MockGameBloc();
    });

    Future<void> pumpPopup(WidgetTester tester) {
      return tester.pumpApp(
        BlocProvider.value(value: gameBloc, child: const SpecialItemPopup()),
      );
    }

    GameState collected(ItemType type, int sequence) {
      return const GameState.initial().copyWith(
        lastSpecialItem: type,
        specialItemSequence: sequence,
      );
    }

    Future<void> emitStates(WidgetTester tester, List<GameState> states) async {
      whenListen(
        gameBloc,
        Stream.fromIterable(states),
        initialState: const GameState.initial(),
      );
      await pumpPopup(tester);
      await tester.pump();
    }

    testWidgets('shows nothing before a special item is collected', (
      tester,
    ) async {
      when(() => gameBloc.state).thenReturn(const GameState.initial());

      await pumpPopup(tester);

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('does not block touches', (tester) async {
      when(() => gameBloc.state).thenReturn(const GameState.initial());

      await pumpPopup(tester);

      expect(
        find.descendant(
          of: find.byType(SpecialItemPopup),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
    });

    testWidgets('shows the medal name and effect', (tester) async {
      await emitStates(tester, [collected(ItemType.medal, 1)]);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Medal'), findsOneWidget);
      expect(find.text('+1000 points'), findsOneWidget);
    });

    testWidgets('shows the zone five name and effect', (tester) async {
      await emitStates(tester, [collected(ItemType.zoneFive, 1)]);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Zone 5'), findsOneWidget);
      expect(find.text('Double jump and protection'), findsOneWidget);
    });

    testWidgets('shows the extra life name and effect', (tester) async {
      await emitStates(tester, [collected(ItemType.extraLife, 1)]);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Extra life'), findsOneWidget);
      expect(find.text('+1 life'), findsOneWidget);
    });

    testWidgets('fades in and disappears after the total duration', (
      tester,
    ) async {
      await emitStates(tester, [collected(ItemType.medal, 1)]);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Medal'), findsOneWidget);

      await tester.pump(SpecialItemPopup.enterDuration);
      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 1);

      await tester.pump(SpecialItemPopup.totalDuration);
      expect(find.text('Medal'), findsNothing);
    });

    testWidgets('restarts with the new item when another one arrives', (
      tester,
    ) async {
      await emitStates(tester, [
        collected(ItemType.medal, 1),
        collected(ItemType.extraLife, 2),
      ]);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Medal'), findsNothing);
      expect(find.text('Extra life'), findsOneWidget);
    });

    testWidgets('restarts for two equal items in a row', (tester) async {
      final controller = StreamController<GameState>.broadcast();
      addTearDown(controller.close);
      whenListen(
        gameBloc,
        controller.stream,
        initialState: const GameState.initial(),
      );
      await pumpPopup(tester);

      controller.add(collected(ItemType.medal, 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));

      controller.add(collected(ItemType.medal, 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Medal'), findsOneWidget);
    });
  });
}
