import 'package:moovz_dash/game/procedural/bottom_route.dart';
import 'package:moovz_dash/game/procedural/section_grid.dart';
import 'package:moovz_dash/game/procedural/solidity_table.dart';
import 'package:moovz_dash/game/procedural/tunnel.dart';

class RouteClearance {
  const RouteClearance({required this.solidity});

  final SolidityTable solidity;

  void clear(SectionGrid grid, BottomRoute route) {
    for (var column = 0; column < route.length; column++) {
      if (route.isGap(column)) {
        _clearGapColumn(grid, route, column);
        continue;
      }
      final bottomRow = route.standRowAt(column);
      _clearRows(grid, column, bottomRow - Tunnel.clearHeight + 1, bottomRow);
    }
  }

  void _clearGapColumn(SectionGrid grid, BottomRoute route, int column) {
    final floorRow = route.surfaceRowAt(column);
    final bottomRow = floorRow - 1;
    final topRow = bottomRow - Tunnel.clearHeight + 1;
    final hazard = _firstHazard(grid, column, topRow, bottomRow);
    final spikes = _firstSpikes(grid, column, topRow, bottomRow);
    _clearRows(grid, column, topRow, bottomRow);
    if (hazard != 0 && !_hasHazardFrom(grid, column, floorRow)) {
      grid.setTile(SectionGrid.groundLayer, column, floorRow, hazard);
    }
    if (spikes != 0) {
      grid.setTile(SectionGrid.spikesLayer, column, bottomRow, spikes);
    }
  }

  int _firstHazard(SectionGrid grid, int column, int top, int bottom) {
    for (var row = bottom; row >= top; row--) {
      final gid = grid.tileAt(SectionGrid.groundLayer, column, row);
      if (solidity.isHazard(gid)) return gid;
    }
    return 0;
  }

  int _firstSpikes(SectionGrid grid, int column, int top, int bottom) {
    for (var row = bottom; row >= top; row--) {
      final gid = grid.tileAt(SectionGrid.spikesLayer, column, row);
      if (gid != 0) return gid;
    }
    return 0;
  }

  bool _hasHazardFrom(SectionGrid grid, int column, int fromRow) {
    for (var row = fromRow; row < grid.height; row++) {
      if (solidity.isHazard(
        grid.tileAt(SectionGrid.groundLayer, column, row),
      )) {
        return true;
      }
    }
    return false;
  }

  void _clearRows(SectionGrid grid, int column, int top, int bottom) {
    for (var row = top; row <= bottom; row++) {
      grid
        ..setTile(SectionGrid.groundLayer, column, row, 0)
        ..setTile(SectionGrid.spikesLayer, column, row, 0);
    }
  }
}
