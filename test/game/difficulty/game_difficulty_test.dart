import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';

void main() {
  group('GameDifficulty', () {
    test('has expected values', () {
      expect(GameDifficulty.easy.playerSpeed, 4.0);
      expect(GameDifficulty.easy.enemyKeepRatio, 0.4);
      expect(GameDifficulty.easy.maxChunkDifficulty, 2);
      expect(GameDifficulty.medium.playerSpeed, 5.0);
      expect(GameDifficulty.medium.enemyKeepRatio, 0.7);
      expect(GameDifficulty.medium.maxChunkDifficulty, 2);
      expect(GameDifficulty.hard.playerSpeed, 5.75);
      expect(GameDifficulty.hard.enemyKeepRatio, 1.0);
      expect(GameDifficulty.hard.maxChunkDifficulty, 3);
    });

    test('fromStorageKey resolves keys and defaults to medium', () {
      for (final difficulty in GameDifficulty.values) {
        expect(
          GameDifficulty.fromStorageKey(difficulty.storageKey),
          difficulty,
        );
      }
      expect(GameDifficulty.fromStorageKey('x'), GameDifficulty.medium);
    });
  });
}
