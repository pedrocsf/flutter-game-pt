// ignore_for_file: cascade_invocations

import 'package:bloc_test/bloc_test.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/audio/audio.dart';
import 'package:moovz_dash/game/game.dart';

class _MockGameBloc extends MockBloc<GameEvent, GameState>
    implements GameBloc {}

class _MockAudioController extends Mock implements AudioController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MoovzDashGame', () {
    late GameBloc gameBloc;
    late AudioController audioController;

    setUp(() {
      gameBloc = _MockGameBloc();
      audioController = _MockAudioController();

      when(() => gameBloc.state).thenReturn(const GameState.initial());
    });

    MoovzDashGame createGame() {
      return MoovzDashGame(
        gameBloc: gameBloc,
        audioController: audioController,
      );
    }

    final flameTester = FlameTester(createGame);

    test('each match starts with a different seed', () {
      final game = createGame();
      final seeds = <int>{};
      for (var match = 0; match < 5; match++) {
        game.startNewMatch();
        seeds.add(game.matchSeed);
      }
      expect(seeds.length, greaterThan(1));
    });

    flameTester.testGameWidget(
      'starts with score 0',
      setUp: (game, tester) async {
        when(() => game.gameBloc.state).thenReturn(const GameState.initial());
        await game.ready();
      },
      verify: (game, tester) async => expect(game.gameBloc.state.score, isZero),
    );

    flameTester.testGameWidget(
      'starts with player',
      setUp: (game, tester) async {
        await game.ready();
      },
      verify: (game, tester) async =>
          expect(game.world.descendants().whereType<Player>(), isNotNull),
    );

    flameTester.testGameWidget(
      'starts with an input',
      setUp: (game, tester) async {
        await game.ready();
      },
      verify: (game, tester) async => expect(
        game.descendants().whereType<KeyboardListenerComponent>(),
        isNotNull,
      ),
    );

    testWithGame(
      'starts with correct amount of items',
      createGame,
      (game) async {
        await game.ready();
        expect(game.leapMap.children.whereType<Item>().length, equals(33));
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: true, // TODO(all): This test is flaky, skipping it for now
    );

    testWithGame(
      'starts with 0 enemies spawned',
      createGame,
      (game) async {
        await game.ready();
        expect(game.leapMap.children.whereType<Enemy>().length, isZero);
      },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: true, // TODO(all): This test is flaky, skipping it for now
    );

    group('input', () {
      late MoovzDashGame game;
      late int jumps;
      late int slides;

      setUp(() {
        game = createGame();
        jumps = 0;
        slides = 0;
        game
          ..addJumpListener(() => jumps++)
          ..addSlideListener(() => slides++);
      });

      test('triggerJump only notifies jump listeners', () {
        game.triggerJump();

        expect(jumps, 1);
        expect(slides, isZero);
      });

      test('triggerSlide only notifies slide listeners', () {
        game.triggerSlide();

        expect(slides, 1);
        expect(jumps, isZero);
      });

      test('the legacy input listener is a jump listener', () {
        var legacyCalls = 0;
        void legacy() => legacyCalls++;
        game.addInputListener(legacy);

        game.triggerJump();
        game.triggerSlide();
        expect(legacyCalls, 1);

        game.removeInputListener(legacy);
        game.triggerJump();
        expect(legacyCalls, 1);
      });

      test('removed listeners are no longer notified', () {
        void listener() => jumps++;
        game
          ..addJumpListener(listener)
          ..removeJumpListener(listener)
          ..triggerJump();

        expect(jumps, 1);
      });

      test('jumping dismisses the tap to jump overlay', () {
        game.overlays.addEntry('tapToJump', (_, _) => const SizedBox());
        game.overlays.add('tapToJump');

        game.triggerSlide();
        expect(game.overlays.isActive('tapToJump'), isTrue);

        game.triggerJump();
        expect(game.overlays.isActive('tapToJump'), isFalse);
      });

      test('a tap jumps when the pointer is released', () {
        game.handlePointerDown(const PointerDownEvent(pointer: 1));
        expect(jumps, isZero);

        game.handlePointerUp(const PointerUpEvent(pointer: 1));
        expect(jumps, 1);
        expect(slides, isZero);
      });

      test('dragging down slides without waiting for the release', () {
        game
          ..handlePointerDown(const PointerDownEvent(pointer: 1))
          ..handlePointerMove(
            const PointerMoveEvent(pointer: 1, position: Offset(0, 40)),
          );

        expect(slides, 1);
        expect(jumps, isZero);
      });

      test('dragging up jumps without waiting for the release', () {
        game
          ..handlePointerDown(
            const PointerDownEvent(pointer: 1, position: Offset(0, 100)),
          )
          ..handlePointerMove(
            const PointerMoveEvent(pointer: 1, position: Offset(0, 60)),
          );

        expect(jumps, 1);
        expect(slides, isZero);

        game.handlePointerUp(
          const PointerUpEvent(pointer: 1, position: Offset(0, 60)),
        );
        expect(jumps, 1);
      });

      test('a cancelled pointer does nothing', () {
        game
          ..handlePointerDown(const PointerDownEvent(pointer: 1))
          ..handlePointerCancel(const PointerCancelEvent(pointer: 1))
          ..handlePointerUp(const PointerUpEvent(pointer: 1));

        expect(jumps, isZero);
        expect(slides, isZero);
      });

      test('keyboard keys jump and slide', () {
        final keyboard = game.buildKeyboardListener();

        void press(LogicalKeyboardKey key) {
          keyboard.onKeyEvent(
            KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.space,
              logicalKey: key,
              timeStamp: Duration.zero,
            ),
            {key},
          );
        }

        press(LogicalKeyboardKey.space);
        press(LogicalKeyboardKey.arrowUp);
        expect(jumps, 2);
        expect(slides, isZero);

        press(LogicalKeyboardKey.arrowDown);
        press(LogicalKeyboardKey.keyS);
        expect(slides, 2);
        expect(jumps, 2);
      });
    });
  });
}
