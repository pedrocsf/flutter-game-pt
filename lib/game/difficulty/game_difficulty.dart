enum GameDifficulty {
  easy(
    playerSpeed: 4,
    enemyKeepRatio: 0.4,
    maxChunkDifficulty: 2,
    storageKey: 'easy',
  ),
  medium(
    playerSpeed: 5,
    enemyKeepRatio: 0.7,
    maxChunkDifficulty: 2,
    storageKey: 'medium',
  ),
  hard(
    playerSpeed: 5.75,
    enemyKeepRatio: 1,
    maxChunkDifficulty: 3,
    storageKey: 'hard',
  );

  const GameDifficulty({
    required this.playerSpeed,
    required this.enemyKeepRatio,
    required this.maxChunkDifficulty,
    required this.storageKey,
  });

  final double playerSpeed;
  final double enemyKeepRatio;
  final int maxChunkDifficulty;
  final String storageKey;

  static GameDifficulty fromStorageKey(String key) {
    return GameDifficulty.values.firstWhere(
      (difficulty) => difficulty.storageKey == key,
      orElse: () => GameDifficulty.medium,
    );
  }
}
