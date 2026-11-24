import 'package:moovz_dash/game/procedural/bottom_route.dart';
import 'package:moovz_dash/game/procedural/buried_path_detector.dart';
import 'package:moovz_dash/game/procedural/section_grid.dart';
import 'package:moovz_dash/game/procedural/solidity_table.dart';
import 'package:moovz_dash/game/procedural/tunnel.dart';
import 'package:moovz_dash/game/procedural/tunnel_digger.dart';
import 'package:moovz_dash/game/procedural/tunnel_tiles.dart';

class BuriedPathCarver {
  BuriedPathCarver({required this.solidity, required this.tiles})
    : _detector = BuriedPathDetector(tiles: tiles, solidity: solidity),
      _digger = TunnelDigger(solidity: solidity, tiles: tiles);

  final SolidityTable solidity;
  final TunnelTiles tiles;
  final BuriedPathDetector _detector;
  final TunnelDigger _digger;

  List<Tunnel> carve(SectionGrid grid, BottomRoute route) {
    final tunnels = [
      for (final run in _detector.detect(grid, route)) ..._tunnelsOf(run),
    ];
    for (final tunnel in tunnels) {
      _digger.dig(grid, tunnel);
    }
    return tunnels;
  }

  List<Tunnel> _tunnelsOf(BuriedRun run) {
    final tunnels = <Tunnel>[];
    var segmentFirst = run.firstColumn;
    for (
      var column = run.firstColumn + 1;
      column <= run.lastColumn + 1;
      column++
    ) {
      final isEnd = column > run.lastColumn;
      final changesRow =
          !isEnd && _rowAt(run, column) != _rowAt(run, segmentFirst);
      if (!isEnd && !changesRow) continue;
      tunnels.add(
        Tunnel(
          firstColumn: segmentFirst,
          lastColumn: column - 1,
          standRow: _rowAt(run, segmentFirst),
          kind: TunnelKind.buriedPath,
          startsPath: segmentFirst == run.firstColumn,
          endsPath: isEnd,
          explicitPathFirstColumn: run.firstColumn,
        ),
      );
      segmentFirst = column;
    }
    return tunnels;
  }

  int _rowAt(BuriedRun run, int column) {
    return run.standRows[column - run.firstColumn];
  }
}
