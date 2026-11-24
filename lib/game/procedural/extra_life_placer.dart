import 'dart:math';

import 'package:moovz_dash/game/difficulty/game_difficulty.dart';
import 'package:moovz_dash/game/procedural/chunk_library.dart';

class ExtraLifePlacer {
  const ExtraLifePlacer({required this.tileSize});

  static const chances = {
    GameDifficulty.easy: 0.60,
    GameDifficulty.medium: 0.45,
    GameDifficulty.hard: 0.30,
  };

  static const typeProperty = 'Type';
  static const extraLifeType = 'ExtraLife';
  static const secondHalfStartRatio = 0.5;

  final double tileSize;

  List<ChunkObject> place({
    required List<ChunkObject> items,
    required int sectionWidth,
    required GameDifficulty difficulty,
    required Random random,
  }) {
    final candidates = _energyIndexes(items);
    if (candidates.isEmpty) return items;
    if (random.nextDouble() >= chances[difficulty]!) return items;
    final pool = _preferSecondHalf(items, candidates, sectionWidth);
    final chosen = pool[random.nextInt(pool.length)];
    return [
      for (var index = 0; index < items.length; index++)
        index == chosen ? _asExtraLife(items[index]) : items[index],
    ];
  }

  List<int> _energyIndexes(List<ChunkObject> items) {
    return [
      for (var index = 0; index < items.length; index++)
        if (!items[index].properties.containsKey(typeProperty)) index,
    ];
  }

  List<int> _preferSecondHalf(
    List<ChunkObject> items,
    List<int> candidates,
    int sectionWidth,
  ) {
    final halfway = sectionWidth * tileSize * secondHalfStartRatio;
    final later = candidates.where((index) => items[index].x >= halfway);
    return later.isEmpty ? candidates : later.toList();
  }

  ChunkObject _asExtraLife(ChunkObject item) {
    return ChunkObject(
      x: item.x,
      y: item.y,
      width: item.width,
      height: item.height,
      gid: item.gid,
      type: item.type,
      properties: {...item.properties, typeProperty: extraLifeType},
    );
  }
}
