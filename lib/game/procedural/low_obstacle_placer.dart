import 'dart:math';

import 'package:moovz_dash/game/difficulty/game_difficulty.dart';
import 'package:moovz_dash/game/procedural/chunk_library.dart';
import 'package:moovz_dash/game/procedural/section_grid.dart';
import 'package:moovz_dash/game/procedural/solidity_table.dart';
import 'package:moovz_dash/game/procedural/tunnel.dart';

typedef StandSpot = ({int column, int row});

class LowObstacleDensity {
  const LowObstacleDensity({
    required this.columnsPerBar,
    required this.minMobs,
    required this.maxMobs,
  });

  final int columnsPerBar;
  final int minMobs;
  final int maxMobs;

  bool get hasBars => columnsPerBar > 0;

  bool get hasMobs => maxMobs > 0;
}

class LowObstaclePlacer {
  LowObstaclePlacer({
    required this.solidity,
    required this.enemyGid,
    required this.tileSize,
  });

  static const densities = {
    GameDifficulty.easy: LowObstacleDensity(
      columnsPerBar: 0,
      minMobs: 0,
      maxMobs: 0,
    ),
    GameDifficulty.medium: LowObstacleDensity(
      columnsPerBar: 10,
      minMobs: 1,
      maxMobs: 2,
    ),
    GameDifficulty.hard: LowObstacleDensity(
      columnsPerBar: 6,
      minMobs: 2,
      maxMobs: 5,
    ),
  };

  static const lowBarType = 'LowBar';
  static const mobTypes = ['FatigueHourglass', 'LazyCloud', 'Bandage'];
  static const lowProperty = 'Low';
  static const typeProperty = 'Type';
  static const flatMargin = 3;
  static const spawnClearance = 6;
  static const endClearance = 6;
  static const respawnClearance = 1;
  static const barEnemyClearance = 1;
  static const mobEnemyClearance = 2;
  static const barSpacing = 4;
  static const mobSpacing = 6;
  static const barWidth = 64.0;
  static const barHeight = 20.0;
  static const barRiseAboveFloor = 42.0;
  static const mobSize = 32.0;
  static const mobRiseAboveFloor = 54.0;

  final SolidityTable solidity;
  final int enemyGid;
  final double tileSize;

  List<ChunkObject> place({
    required SectionGrid grid,
    required List<Tunnel> tunnels,
    required Map<String, List<ChunkObject>> objects,
    required GameDifficulty difficulty,
    required Random random,
  }) {
    final density = densities[difficulty]!;
    final bars = density.hasBars
        ? _placeBars(
            grid,
            tunnels,
            density,
            _blockedColumns(grid, objects, barEnemyClearance),
            random,
          )
        : <ChunkObject>[];
    final mobs = density.hasMobs
        ? _placeMobs(
            grid,
            tunnels,
            density,
            _blockedColumns(grid, objects, mobEnemyClearance),
            random,
          )
        : <ChunkObject>[];
    return [...bars, ...mobs];
  }

  Set<int> _blockedColumns(
    SectionGrid grid,
    Map<String, List<ChunkObject>> objects,
    int enemyClearance,
  ) {
    final blocked = <int>{};
    void block(Iterable<ChunkObject> items, int clearance) {
      for (final item in items) {
        final column = (item.x / tileSize).floor();
        for (var offset = -clearance; offset <= clearance; offset++) {
          blocked.add(column + offset);
        }
      }
    }

    block(objects['spawn'] ?? const [], spawnClearance);
    block(objects['respawn'] ?? const [], respawnClearance);
    block(objects['enemies'] ?? const [], enemyClearance);
    for (var offset = 0; offset < endClearance; offset++) {
      blocked.add(grid.width - 1 - offset);
    }
    return blocked;
  }

  List<ChunkObject> _placeBars(
    SectionGrid grid,
    List<Tunnel> tunnels,
    LowObstacleDensity density,
    Set<int> blocked,
    Random random,
  ) {
    final bars = <ChunkObject>[];
    for (final tunnel in tunnels) {
      final candidates = _barCandidates(grid, tunnel);
      final count = _barCount(tunnel, density, random);
      final spots = _pickSpots(candidates, count, barSpacing, blocked, random);
      bars.addAll(spots.map(_barAt));
    }
    return bars;
  }

  int _barCount(Tunnel tunnel, LowObstacleDensity density, Random random) {
    final perBar = density.columnsPerBar;
    final remainder = (tunnel.length % perBar) / perBar;
    final extra = random.nextDouble() < remainder ? 1 : 0;
    return tunnel.length ~/ perBar + extra;
  }

  List<StandSpot> _barCandidates(SectionGrid grid, Tunnel tunnel) {
    return [
      for (
        var column = tunnel.firstColumn;
        column <= tunnel.lastColumn;
        column++
      )
        if (_isFlatStand(grid, column, tunnel.standRow))
          (column: column, row: tunnel.standRow),
    ];
  }

  List<ChunkObject> _placeMobs(
    SectionGrid grid,
    List<Tunnel> tunnels,
    LowObstacleDensity density,
    Set<int> blocked,
    Random random,
  ) {
    final candidates = _mobCandidates(grid, tunnels);
    final span = density.maxMobs - density.minMobs + 1;
    final count = density.minMobs + random.nextInt(span);
    final spots = _pickSpots(candidates, count, mobSpacing, blocked, random);
    return spots.map((spot) => _mobAt(spot, random)).toList();
  }

  List<StandSpot> _mobCandidates(SectionGrid grid, List<Tunnel> tunnels) {
    final spots = <StandSpot>[];
    for (var column = 0; column < grid.width; column++) {
      if (_windowTouchesTunnel(tunnels, column)) continue;
      for (var row = 1; row < grid.height - 1; row++) {
        if (_isFlatStand(grid, column, row)) {
          spots.add((column: column, row: row));
        }
      }
    }
    return spots;
  }

  bool _windowTouchesTunnel(List<Tunnel> tunnels, int column) {
    return tunnels.any(
      (tunnel) =>
          tunnel.lastColumn >= column - flatMargin &&
          tunnel.firstColumn <= column + flatMargin,
    );
  }

  bool _isFlatStand(SectionGrid grid, int column, int row) {
    for (var offset = -flatMargin; offset <= flatMargin; offset++) {
      if (!_isSafeStand(grid, column + offset, row)) return false;
    }
    return true;
  }

  bool _isSafeStand(SectionGrid grid, int column, int row) {
    const ground = SectionGrid.groundLayer;
    const spikes = SectionGrid.spikesLayer;
    return grid.tileAt(ground, column, row) == 0 &&
        grid.tileAt(ground, column, row - 1) == 0 &&
        solidity.isPlainFloor(grid.tileAt(ground, column, row + 1)) &&
        grid.tileAt(spikes, column, row) == 0 &&
        grid.tileAt(spikes, column, row + 1) == 0;
  }

  List<StandSpot> _pickSpots(
    List<StandSpot> candidates,
    int count,
    int spacing,
    Set<int> blocked,
    Random random,
  ) {
    final pool = List<StandSpot>.of(candidates);
    final picked = <StandSpot>[];
    while (picked.length < count && pool.isNotEmpty) {
      final spot = pool.removeAt(random.nextInt(pool.length));
      if (blocked.contains(spot.column)) continue;
      final isCrowded = picked.any(
        (other) => (other.column - spot.column).abs() < spacing,
      );
      if (!isCrowded) picked.add(spot);
    }
    return picked;
  }

  ChunkObject _barAt(StandSpot spot) {
    return ChunkObject(
      x: spot.column * tileSize,
      y: (spot.row + 1) * tileSize - barRiseAboveFloor,
      width: barWidth,
      height: barHeight,
      gid: enemyGid,
      type: '',
      properties: const {typeProperty: lowBarType, lowProperty: true},
    );
  }

  ChunkObject _mobAt(StandSpot spot, Random random) {
    return ChunkObject(
      x: spot.column * tileSize + (tileSize - mobSize) / 2,
      y: (spot.row + 1) * tileSize - mobRiseAboveFloor,
      width: mobSize,
      height: mobSize,
      gid: enemyGid,
      type: '',
      properties: {
        typeProperty: mobTypes[random.nextInt(mobTypes.length)],
        lowProperty: true,
      },
    );
  }
}
