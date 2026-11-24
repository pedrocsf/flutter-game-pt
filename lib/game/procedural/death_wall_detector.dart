import 'package:moovz_dash/game/procedural/section_grid.dart';
import 'package:moovz_dash/game/procedural/solidity_table.dart';

class DeathWallDetector {
  const DeathWallDetector({required this.solidity});

  static const wallHeight = 3;

  final SolidityTable solidity;

  bool isDeathWall(SectionGrid grid, int column, int row) {
    if (column + 1 >= grid.width || row + 1 >= grid.height) return false;
    if (_isSolidAt(grid, column, row)) return false;
    final floor = grid.tileAt(SectionGrid.groundLayer, column, row + 1);
    if (!solidity.isStandable(floor)) return false;
    return List.generate(
      wallHeight,
      (offset) => _isSolidAt(grid, column + 1, row - offset),
    ).every((isSolid) => isSolid);
  }

  bool _isSolidAt(SectionGrid grid, int column, int row) {
    return solidity.isSolid(grid.tileAt(SectionGrid.groundLayer, column, row));
  }
}
