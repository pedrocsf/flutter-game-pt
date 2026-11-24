import 'package:moovz_dash/game/procedural/bottom_route.dart';
import 'package:moovz_dash/game/procedural/hazard_span.dart';
import 'package:moovz_dash/game/procedural/section_grid.dart';
import 'package:moovz_dash/game/procedural/solidity_table.dart';

class _RouteStep {
  const _RouteStep(this.row, {this.needsFloor = false});

  final int row;
  final bool needsFloor;
}

class RoutePlanner {
  const RoutePlanner({required this.solidity});

  static const maxStepUp = 2;
  static const maxGapDrop = 2;
  static const gapRunUpColumns = 3;

  final SolidityTable solidity;

  BottomRoute plan(
    SectionGrid grid, {
    List<HazardSpan> jumpableSpans = const [],
  }) {
    final rows = <int>[];
    final fillColumns = <int>{};
    final gaps = <HazardSpan>[];
    var previous = _initialRow(grid);
    var column = 0;
    while (column < grid.width) {
      final gap = column == 0
          ? null
          : _gapAt(grid, jumpableSpans, column, previous);
      if (gap != null) {
        gaps.add(gap);
        rows.addAll(List.filled(gap.width, previous));
        column = gap.lastColumn + 1;
        continue;
      }
      final step = column == 0
          ? _RouteStep(previous)
          : _stepAt(
              grid,
              column,
              previous,
              keepsLevel: _isGapRunUp(jumpableSpans, column),
            );
      if (step.needsFloor) fillColumns.add(column);
      rows.add(step.row);
      previous = step.row;
      column++;
    }
    return BottomRoute(rows: rows, gaps: gaps, fillColumns: fillColumns);
  }

  int _initialRow(SectionGrid grid) {
    for (var column = 0; column < grid.width; column++) {
      final surfaces = surfaceRows(grid, column);
      if (surfaces.isNotEmpty) return surfaces.last;
    }
    return grid.height - 1;
  }

  List<int> surfaceRows(SectionGrid grid, int column) {
    final ground = grid.columnOf(SectionGrid.groundLayer, column);
    return [
      for (var row = 0; row < ground.length; row++)
        if (_isSurface(ground, row)) row,
    ];
  }

  bool _isSurface(List<int> ground, int row) {
    if (!solidity.isStandable(ground[row])) return false;
    final above = row == 0 ? 0 : ground[row - 1];
    return !solidity.isSolid(above);
  }

  HazardSpan? _gapAt(
    SectionGrid grid,
    List<HazardSpan> spans,
    int column,
    int entryRow,
  ) {
    for (final span in spans) {
      if (span.firstColumn != column) continue;
      final isGap =
          _lacksFloor(grid, span, entryRow) &&
          _hasReachableExit(grid, span, entryRow);
      return isGap ? span : null;
    }
    return null;
  }

  bool _lacksFloor(SectionGrid grid, HazardSpan span, int entryRow) {
    for (var column = span.firstColumn; column <= span.lastColumn; column++) {
      final floor = grid.tileAt(SectionGrid.groundLayer, column, entryRow);
      if (!solidity.isStandable(floor)) return true;
    }
    return false;
  }

  bool _hasReachableExit(SectionGrid grid, HazardSpan span, int entryRow) {
    final surfaces = surfaceRows(grid, span.lastColumn + 1);
    if (surfaces.isEmpty) return false;
    final exitRow = surfaces.reduce(
      (best, row) =>
          (row - entryRow).abs() <= (best - entryRow).abs() ? row : best,
    );
    return exitRow <= entryRow + maxGapDrop && exitRow >= entryRow - maxStepUp;
  }

  bool _isGapRunUp(List<HazardSpan> spans, int column) {
    return spans.any(
      (span) =>
          column < span.firstColumn &&
          column >= span.firstColumn - gapRunUpColumns,
    );
  }

  _RouteStep _stepAt(
    SectionGrid grid,
    int column,
    int previous, {
    required bool keepsLevel,
  }) {
    final floor = grid.tileAt(SectionGrid.groundLayer, column, previous);
    if (solidity.isStandable(floor)) {
      if (keepsLevel) return _RouteStep(previous);
      final top = _stepTop(grid, column, previous);
      return _RouteStep(previous - top <= maxStepUp ? top : previous);
    }
    if (floor != 0) return _RouteStep(previous, needsFloor: true);
    final landing = _landingRow(grid, column, previous + 1);
    if (landing == null) return _RouteStep(previous, needsFloor: true);
    return _RouteStep(landing);
  }

  int _stepTop(SectionGrid grid, int column, int floorRow) {
    var top = floorRow;
    while (top > 0 &&
        _isStepCell(grid.tileAt(SectionGrid.groundLayer, column, top - 1))) {
      top--;
    }
    return top;
  }

  bool _isStepCell(int gid) {
    final kind = solidity.kindOf(gid);
    return kind == TileKind.solid || kind == TileKind.slope;
  }

  int? _landingRow(SectionGrid grid, int column, int fromRow) {
    for (var row = fromRow; row < grid.height; row++) {
      final gid = grid.tileAt(SectionGrid.groundLayer, column, row);
      if (gid == 0) continue;
      return solidity.isStandable(gid) ? row : null;
    }
    return null;
  }
}
