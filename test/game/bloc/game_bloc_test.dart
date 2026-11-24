// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/bloc/game_bloc.dart';
import 'package:moovz_dash/game/entities/item_type.dart';

void main() {
  group('GameBloc', () {
    blocTest<GameBloc, GameState>(
      'emits GameState initial when GameOver is added',
      build: GameBloc.new,
      seed: () =>
          const GameState(score: 100, currentLevel: 2, currentSection: 2),
      act: (bloc) => bloc.add(GameOver()),
      expect: () => const [GameState.initial()],
    );

    blocTest<GameBloc, GameState>(
      'emits GameState with score increased correctly '
      'when GameScoreIncreased is added',
      build: GameBloc.new,
      seed: () => const GameState.initial().copyWith(score: 100),
      act: (bloc) => bloc.add(GameScoreIncreased(by: 2)),
      expect: () => [const GameState.initial().copyWith(score: 102)],
    );

    blocTest<GameBloc, GameState>(
      'emits GameState with score decreased correctly '
      'when GameScoreDecreased is added',
      build: GameBloc.new,
      seed: () => const GameState.initial().copyWith(score: 100),
      act: (bloc) => bloc.add(GameScoreDecreased(by: 2)),
      expect: () => [const GameState.initial().copyWith(score: 98)],
    );

    blocTest<GameBloc, GameState>(
      'starts with the initial lives',
      build: GameBloc.new,
      verify: (bloc) => expect(bloc.state.lives, GameState.initialLives),
    );

    blocTest<GameBloc, GameState>(
      'removes one life when GameLifeLost is added',
      build: GameBloc.new,
      act: (bloc) => bloc.add(GameLifeLost()),
      expect: () => [
        const GameState.initial().copyWith(lives: GameState.initialLives - 1),
      ],
    );

    blocTest<GameBloc, GameState>(
      'never goes below zero lives',
      build: GameBloc.new,
      seed: () => const GameState.initial().copyWith(lives: 0),
      act: (bloc) => bloc.add(GameLifeLost()),
      expect: () => const <GameState>[],
    );

    blocTest<GameBloc, GameState>(
      'adds one life when GameLifeGained is added',
      build: GameBloc.new,
      act: (bloc) => bloc.add(GameLifeGained()),
      expect: () => [
        const GameState.initial().copyWith(lives: GameState.initialLives + 1),
      ],
    );

    blocTest<GameBloc, GameState>(
      'never goes above the max lives',
      build: GameBloc.new,
      seed: () => const GameState.initial().copyWith(lives: GameState.maxLives),
      act: (bloc) => bloc.add(GameLifeGained()),
      expect: () => const <GameState>[],
    );

    blocTest<GameBloc, GameState>(
      'keeps the lives when a section is completed',
      build: GameBloc.new,
      seed: () => const GameState.initial().copyWith(lives: 2),
      act: (bloc) => bloc.add(GameSectionCompleted(sectionCount: 3)),
      expect: () => [
        const GameState.initial().copyWith(lives: 2, currentSection: 1),
      ],
    );

    blocTest<GameBloc, GameState>(
      'restores the initial lives when GameOver is added',
      build: GameBloc.new,
      seed: () => const GameState.initial().copyWith(lives: 0, score: 50),
      act: (bloc) => bloc.add(GameOver()),
      expect: () => const [GameState.initial()],
    );

    blocTest<GameBloc, GameState>(
      'stores the special item and a sequence when it is collected',
      build: GameBloc.new,
      act: (bloc) => bloc.add(GameSpecialItemCollected(ItemType.medal)),
      expect: () => [
        const GameState.initial().copyWith(
          lastSpecialItem: ItemType.medal,
          specialItemSequence: 1,
        ),
      ],
    );

    blocTest<GameBloc, GameState>(
      'changes the sequence even for two equal special items in a row',
      build: GameBloc.new,
      act: (bloc) => bloc
        ..add(GameSpecialItemCollected(ItemType.extraLife))
        ..add(GameSpecialItemCollected(ItemType.extraLife)),
      expect: () => [
        const GameState.initial().copyWith(
          lastSpecialItem: ItemType.extraLife,
          specialItemSequence: 1,
        ),
        const GameState.initial().copyWith(
          lastSpecialItem: ItemType.extraLife,
          specialItemSequence: 2,
        ),
      ],
    );

    blocTest<GameBloc, GameState>(
      'ignores a regular item as special item',
      build: GameBloc.new,
      act: (bloc) => bloc.add(GameSpecialItemCollected(ItemType.energy)),
      expect: () => const <GameState>[],
    );

    blocTest<GameBloc, GameState>(
      'clears the special item when GameOver is added',
      build: GameBloc.new,
      seed: () => const GameState.initial().copyWith(
        lastSpecialItem: ItemType.zoneFive,
        specialItemSequence: 3,
      ),
      act: (bloc) => bloc.add(GameOver()),
      expect: () => const [GameState.initial()],
    );
  });
}
