// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/bloc/game_bloc.dart';
import 'package:moovz_dash/game/entities/item_type.dart';

void main() {
  group('GameState', () {
    test(
      'initial state score is 0',
      () => expect(GameState.initial().score, isZero),
    );

    test('supports value comparisons', () {
      expect(GameState.initial(), GameState.initial());
    });

    test('returns same object when no properties are passed', () {
      expect(GameState.initial().copyWith(), GameState.initial());
    });

    test('returns object with updated score when score is passed', () {
      expect(
        GameState.initial().copyWith(score: 100),
        GameState(score: 100, currentLevel: 1, currentSection: 0),
      );
    });

    test(
      'returns object with updated scocurrentLevelre when score is passed',
      () {
        expect(
          GameState.initial().copyWith(currentLevel: 2),
          GameState(score: 0, currentLevel: 2, currentSection: 0),
        );
      },
    );

    test('returns object with updated currentSection when score is passed', () {
      expect(
        GameState.initial().copyWith(currentSection: 3),
        GameState(score: 0, currentLevel: 1, currentSection: 3),
      );
    });

    test('initial state has the initial lives and no special item', () {
      final state = GameState.initial();

      expect(state.lives, GameState.initialLives);
      expect(state.lastSpecialItem, isNull);
      expect(state.specialItemSequence, isZero);
    });

    test('returns object with updated lives when lives is passed', () {
      expect(GameState.initial().copyWith(lives: 2).lives, 2);
    });

    test('returns object with updated special item data', () {
      final state = GameState.initial().copyWith(
        lastSpecialItem: ItemType.medal,
        specialItemSequence: 4,
      );

      expect(state.lastSpecialItem, ItemType.medal);
      expect(state.specialItemSequence, 4);
    });

    test('states differing only by the sequence are not equal', () {
      expect(
        GameState.initial().copyWith(specialItemSequence: 1),
        isNot(GameState.initial().copyWith(specialItemSequence: 2)),
      );
    });
  });
}
