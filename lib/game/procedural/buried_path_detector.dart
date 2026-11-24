import 'package:moovz_dash/game/procedural/bottom_route.dart';
import 'package:moovz_dash/game/procedural/section_grid.dart';
import 'package:moovz_dash/game/procedural/solidity_table.dart';
import 'package:moovz_dash/game/procedural/tunnel.dart';
import 'package:moovz_dash/game/procedural/tunnel_tiles.dart';

class BuriedRun {
  const BuriedRun({required this.firstColumn, required this.standRows});

  final int firstColumn;
  final List<int> standRows;

  int get lastColumn => firstColumn + standRows.length - 1;
}

class BuriedPathDetector {
  const BuriedPathDetector({required this.tiles, required this.solidity});

  static const minimumBuriedTiles = 2;
  static const minimumFringeTiles = 1;

  final TunnelTiles tiles;
  final SolidityTable solidity;

  int terrainTilesInCorridor(SectionGrid grid, int column, int standRow) {
    var count = 0;
    for (var row = standRow - Tunnel.clearHeight + 1; row <= standRow; row++) {
      final gid = grid.tileAt(SectionGrid.terrainDecorationLayer, column, row);
      if (gid != 0 && !tiles.isDecoration(gid)) count++;
    }
    return count;
  }

  bool hasCoveredObstruction(SectionGrid grid, int column, int standRow) {
    final topRow = standRow - Tunnel.clearHeight + 1;
    final isObstructed = _anyGroundBetween(grid, column, topRow, standRow);
    if (!isObstructed) return false;
    for (var row = 0; row < topRow; row++) {
      final kind = solidity.kindOf(
        grid.tileAt(SectionGrid.groundLayer, column, row),
      );
      if (kind == TileKind.solid || kind == TileKind.slope) return true;
    }
    return false;
  }

  bool _anyGroundBetween(SectionGrid grid, int column, int top, int bottom) {
    for (var row = top; row <= bottom; row++) {
      final gid = grid.tileAt(SectionGrid.groundLayer, column, row);
      if (gid != 0 && !tiles.isStructure(gid)) return true;
    }
    return false;
  }

  List<BuriedRun> detect(SectionGrid grid, BottomRoute route) {
    final baseProfile = [
      for (var column = 0; column < grid.width; column++)
        route.isGap(column) ? null : route.rows[column],
    ];
    final counts = _countsPerColumn(grid, baseProfile);
    final isCore = [for (final count in counts) _isBuried(count)];
    final isMember = [
      for (var column = 0; column < counts.length; column++)
        isCore[column] || _isFringe(counts, isCore, column),
    ];
    return _runsOf(isMember, baseProfile);
  }

  List<int?> _countsPerColumn(SectionGrid grid, List<int?> baseProfile) {
    return [
      for (var column = 0; column < grid.width; column++)
        _countAt(grid, column, baseProfile[column]),
    ];
  }

  int? _countAt(SectionGrid grid, int column, int? baseRow) {
    if (baseRow == null) return null;
    final standRow = baseRow - 1;
    if (standRow - Tunnel.clearHeight < 0) return null;
    final terrainCount = terrainTilesInCorridor(grid, column, standRow);
    if (hasCoveredObstruction(grid, column, standRow)) {
      return terrainCount < minimumBuriedTiles
          ? minimumBuriedTiles
          : terrainCount;
    }
    return terrainCount;
  }

  bool _isBuried(int? count) => count != null && count >= minimumBuriedTiles;

  bool _isFringe(List<int?> counts, List<bool> isCore, int column) {
    final count = counts[column];
    if (count == null || count < minimumFringeTiles) return false;
    final touchesLeft = column > 0 && isCore[column - 1];
    final touchesRight = column + 1 < counts.length && isCore[column + 1];
    return touchesLeft || touchesRight;
  }

  List<BuriedRun> _runsOf(List<bool> isMember, List<int?> baseProfile) {
    final runs = <BuriedRun>[];
    var column = 0;
    while (column < isMember.length) {
      if (!isMember[column]) {
        column++;
        continue;
      }
      final first = column;
      final standRows = <int>[];
      while (column < isMember.length && isMember[column]) {
        standRows.add(baseProfile[column]! - 1);
        column++;
      }
      runs.add(BuriedRun(firstColumn: first, standRows: standRows));
    }
    return runs;
  }
}
