import 'package:moovz_dash/game/procedural/death_wall_detector.dart';
import 'package:moovz_dash/game/procedural/section_grid.dart';
import 'package:moovz_dash/game/procedural/solidity_table.dart';
import 'package:moovz_dash/game/procedural/tunnel.dart';
import 'package:moovz_dash/game/procedural/tunnel_digger.dart';
import 'package:moovz_dash/game/procedural/tunnel_tiles.dart';

class TunnelCarver {
  TunnelCarver({required this.solidity, required this.tiles})
    : _detector = DeathWallDetector(solidity: solidity),
      _digger = TunnelDigger(solidity: solidity, tiles: tiles);

  static const maxPasses = 12;

  final SolidityTable solidity;
  final TunnelTiles tiles;
  final DeathWallDetector _detector;
  final TunnelDigger _digger;

  List<Tunnel> carve(SectionGrid grid) {
    final tunnels = <Tunnel>[];
    final skipped = <int>{};
    for (var pass = 0; pass < maxPasses; pass++) {
      final carved = _carvePass(grid, tunnels, skipped);
      if (!carved) break;
    }
    return tunnels;
  }

  bool _carvePass(SectionGrid grid, List<Tunnel> tunnels, Set<int> skipped) {
    var carved = false;
    for (var column = 0; column < grid.width - 1; column++) {
      for (var row = 0; row < grid.height - 1; row++) {
        final key = column * grid.height + row;
        if (skipped.contains(key)) continue;
        if (!_detector.isDeathWall(grid, column, row)) continue;
        final tunnel = _tunnelFor(grid, column, row);
        if (tunnel == null) {
          skipped.add(key);
          continue;
        }
        _digger.dig(grid, tunnel);
        tunnels.add(tunnel);
        carved = true;
      }
    }
    return carved;
  }

  Tunnel? _tunnelFor(SectionGrid grid, int wallFootColumn, int row) {
    if (row - Tunnel.clearHeight < 0) return null;
    final firstColumn = wallFootColumn + 1;
    var openColumn = firstColumn;
    while (openColumn < grid.width && !_isOpen(grid, openColumn, row)) {
      openColumn++;
    }
    final lastColumn = openColumn - 1;
    final tunnel = Tunnel(
      firstColumn: firstColumn,
      lastColumn: lastColumn,
      standRow: row,
    );
    return _touchesStructure(grid, tunnel) ? null : tunnel;
  }

  bool _isOpen(SectionGrid grid, int column, int standRow) {
    return List.generate(
      Tunnel.clearHeight,
      (offset) =>
          grid.tileAt(SectionGrid.groundLayer, column, standRow - offset),
    ).every((gid) => gid == 0);
  }

  bool _touchesStructure(SectionGrid grid, Tunnel tunnel) {
    for (
      var column = tunnel.firstColumn;
      column <= tunnel.lastColumn;
      column++
    ) {
      for (var row = tunnel.topRow; row <= tunnel.standRow; row++) {
        final gid = grid.tileAt(SectionGrid.groundLayer, column, row);
        if (tiles.isStructure(gid)) return true;
      }
    }
    return false;
  }
}
