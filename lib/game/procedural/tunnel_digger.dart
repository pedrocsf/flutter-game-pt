import 'package:moovz_dash/game/procedural/section_grid.dart';
import 'package:moovz_dash/game/procedural/solidity_table.dart';
import 'package:moovz_dash/game/procedural/tunnel.dart';
import 'package:moovz_dash/game/procedural/tunnel_tiles.dart';

class TunnelDigger {
  const TunnelDigger({required this.solidity, required this.tiles});

  static const lampSpacing = 4;
  static const lampOffset = 2;
  static const ledRowIndex = Tunnel.clearHeight - 2;

  final SolidityTable solidity;
  final TunnelTiles tiles;

  void dig(SectionGrid grid, Tunnel tunnel) {
    for (
      var column = tunnel.firstColumn;
      column <= tunnel.lastColumn;
      column++
    ) {
      _clearInterior(grid, tunnel, column);
      _buildRoof(grid, tunnel, column);
      _buildFloor(grid, tunnel, column);
      _paintBackground(grid, tunnel, column);
    }
  }

  void _clearInterior(SectionGrid grid, Tunnel tunnel, int column) {
    for (var row = tunnel.topRow; row <= tunnel.standRow; row++) {
      grid
        ..setTile(SectionGrid.groundLayer, column, row, 0)
        ..setTile(SectionGrid.spikesLayer, column, row, 0)
        ..setTile(SectionGrid.terrainDecorationLayer, column, row, 0)
        ..setTile(SectionGrid.decorationLayer, column, row, 0);
    }
  }

  void _buildRoof(SectionGrid grid, Tunnel tunnel, int column) {
    if (!_acceptsRoof(grid, tunnel, column)) return;
    grid.setTile(
      SectionGrid.groundLayer,
      column,
      tunnel.roofRow,
      tiles.gid(_roofTileId(tunnel, column)),
    );
  }

  bool _acceptsRoof(SectionGrid grid, Tunnel tunnel, int column) {
    if (tunnel.kind == TunnelKind.wallCut) return true;
    final existing = grid.tileAt(
      SectionGrid.groundLayer,
      column,
      tunnel.roofRow,
    );
    if (existing != 0) return false;
    return _hasGroundAbove(grid, column, tunnel.roofRow);
  }

  bool _hasGroundAbove(SectionGrid grid, int column, int roofRow) {
    for (var row = 0; row < roofRow; row++) {
      if (grid.tileAt(SectionGrid.groundLayer, column, row) != 0) return true;
    }
    return false;
  }

  int _roofTileId(Tunnel tunnel, int column) {
    if (column == tunnel.pathFirstColumn && column == tunnel.firstColumn) {
      return TunnelTiles.roofStart;
    }
    if (column == tunnel.lastColumn && tunnel.endsPath) {
      return TunnelTiles.roofEnd;
    }
    final isLamp =
        (column - tunnel.pathFirstColumn) % lampSpacing == lampOffset;
    return isLamp ? TunnelTiles.roofLamp : TunnelTiles.roofMiddle;
  }

  void _buildFloor(SectionGrid grid, Tunnel tunnel, int column) {
    final surface = grid.tileAt(
      SectionGrid.groundLayer,
      column,
      tunnel.floorRow,
    );
    grid.setTile(SectionGrid.spikesLayer, column, tunnel.floorRow, 0);
    if (solidity.isStandable(surface)) return;
    grid.setTile(
      SectionGrid.groundLayer,
      column,
      tunnel.floorRow,
      tiles.gid(TunnelTiles.floorTop),
    );
    _fillBeneath(grid, tunnel, column);
  }

  void _fillBeneath(SectionGrid grid, Tunnel tunnel, int column) {
    if (_hasGroundBeneath(grid, tunnel, column)) return;
    for (var row = tunnel.floorRow + 1; row < grid.height; row++) {
      grid
        ..setTile(
          SectionGrid.groundLayer,
          column,
          row,
          tiles.gid(TunnelTiles.floorFill),
        )
        ..setTile(SectionGrid.spikesLayer, column, row, 0);
    }
  }

  bool _hasGroundBeneath(SectionGrid grid, Tunnel tunnel, int column) {
    for (var row = tunnel.floorRow + 1; row < grid.height; row++) {
      final gid = grid.tileAt(SectionGrid.groundLayer, column, row);
      if (gid != 0 && !solidity.isHazard(gid)) return true;
    }
    return false;
  }

  void _paintBackground(SectionGrid grid, Tunnel tunnel, int column) {
    final archId = _archTileId(tunnel, column);
    for (var row = tunnel.topRow; row <= tunnel.standRow; row++) {
      final localId = archId ?? _backgroundTileId(row - tunnel.topRow);
      grid.setTile(
        SectionGrid.terrainDecorationLayer,
        column,
        row,
        tiles.gid(localId),
      );
    }
  }

  int? _archTileId(Tunnel tunnel, int column) {
    if (column == tunnel.firstColumn && tunnel.startsPath) {
      return TunnelTiles.entryArch;
    }
    if (column == tunnel.lastColumn && tunnel.endsPath) {
      return TunnelTiles.exitArch;
    }
    return null;
  }

  int _backgroundTileId(int rowOffset) {
    if (rowOffset == 0) return TunnelTiles.backgroundTop;
    if (rowOffset == Tunnel.clearHeight - 1) return TunnelTiles.backgroundBase;
    if (rowOffset == ledRowIndex) return TunnelTiles.backgroundLed;
    return TunnelTiles.backgroundMiddle;
  }
}
