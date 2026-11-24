import 'package:moovz_dash/game/procedural/bottom_route.dart';
import 'package:moovz_dash/game/procedural/hazard_span.dart';
import 'package:moovz_dash/game/procedural/route_planner.dart';
import 'package:moovz_dash/game/procedural/section_grid.dart';
import 'package:moovz_dash/game/procedural/solidity_table.dart';

class BaseFloorResult {
  const BaseFloorResult({
    required this.extendedColumns,
    required this.preservedSpans,
    required this.route,
  });

  final int extendedColumns;
  final List<HazardSpan> preservedSpans;
  final BottomRoute route;
}

class BaseFloorExtender {
  const BaseFloorExtender({required this.solidity});

  static const dropTolerance = 2;

  final SolidityTable solidity;

  int? baseRowOf(List<int> groundColumn, {int? near}) {
    final surfaces = _surfaceRows(groundColumn);
    if (surfaces.isEmpty) return null;
    if (near == null) return surfaces.last;
    return surfaces.reduce(
      (best, row) => (row - near).abs() <= (best - near).abs() ? row : best,
    );
  }

  List<int?> baseProfile(
    List<List<int>> groundColumns, {
    List<HazardSpan> preservedSpans = const [],
  }) {
    final profile = <int?>[];
    int? previous;
    for (var column = 0; column < groundColumns.length; column++) {
      final isPreserved = preservedSpans.any(
        (span) => span.containsColumn(column),
      );
      final base = isPreserved
          ? previous
          : baseRowOf(groundColumns[column], near: previous);
      profile.add(base);
      previous = base ?? previous;
    }
    return profile;
  }

  List<int> _surfaceRows(List<int> groundColumn) {
    return [
      for (var row = 0; row < groundColumn.length; row++)
        if (_isSurface(groundColumn, row)) row,
    ];
  }

  bool _isSurface(List<int> groundColumn, int row) {
    if (!solidity.isStandable(groundColumn[row])) return false;
    final above = row == 0 ? 0 : groundColumn[row - 1];
    return !solidity.isSolid(above);
  }

  BaseFloorResult extend(
    SectionGrid grid, {
    List<HazardSpan> jumpableSpans = const [],
  }) {
    final route = RoutePlanner(
      solidity: solidity,
    ).plan(grid, jumpableSpans: jumpableSpans);
    var sourceColumn = 0;
    for (var column = 0; column < grid.width; column++) {
      if (route.isGap(column)) continue;
      if (route.fillColumns.contains(column)) {
        _extendColumn(grid, column, sourceColumn, route.rows[column]);
      }
      sourceColumn = column;
    }
    return BaseFloorResult(
      extendedColumns: route.fillColumns.length,
      preservedSpans: route.gaps,
      route: route,
    );
  }

  List<int> _groundOf(SectionGrid grid, int column) {
    return grid.columnOf(SectionGrid.groundLayer, column);
  }

  void _extendColumn(SectionGrid grid, int column, int sourceColumn, int base) {
    final surface = _surfaceTile(grid, sourceColumn, base);
    for (var row = base; row < grid.height; row++) {
      _copyGround(grid, column, sourceColumn, row, base, surface);
      grid
        ..setTile(
          SectionGrid.terrainDecorationLayer,
          column,
          row,
          grid.tileAt(SectionGrid.terrainDecorationLayer, sourceColumn, row),
        )
        ..setTile(SectionGrid.spikesLayer, column, row, 0);
    }
  }

  void _copyGround(
    SectionGrid grid,
    int column,
    int sourceColumn,
    int row,
    int base,
    int surface,
  ) {
    final copied = row == base
        ? surface
        : grid.tileAt(SectionGrid.groundLayer, sourceColumn, row);
    final gid = solidity.isHazard(copied) ? 0 : copied;
    grid.setTile(SectionGrid.groundLayer, column, row, gid);
  }

  int _surfaceTile(SectionGrid grid, int sourceColumn, int base) {
    final tile = grid.tileAt(SectionGrid.groundLayer, sourceColumn, base);
    if (solidity.kindOf(tile) != TileKind.slope) return tile;
    return _nearestFlatSurface(grid, sourceColumn) ?? tile;
  }

  int? _nearestFlatSurface(SectionGrid grid, int fromColumn) {
    for (var distance = 1; distance < grid.width; distance++) {
      for (final column in [fromColumn - distance, fromColumn + distance]) {
        if (column < 0 || column >= grid.width) continue;
        final row = baseRowOf(_groundOf(grid, column));
        if (row == null) continue;
        final tile = grid.tileAt(SectionGrid.groundLayer, column, row);
        if (solidity.isPlainFloor(tile)) return tile;
      }
    }
    return null;
  }
}
