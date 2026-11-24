import 'package:moovz_dash/game/procedural/hazard_span.dart';

class BottomRoute {
  const BottomRoute({
    required this.rows,
    required this.gaps,
    required this.fillColumns,
  });

  static const empty = BottomRoute(rows: [], gaps: [], fillColumns: {});

  final List<int> rows;
  final List<HazardSpan> gaps;
  final Set<int> fillColumns;

  int get length => rows.length;

  bool isGap(int column) => gaps.any((gap) => gap.containsColumn(column));

  int surfaceRowAt(int column) => rows[column];

  int standRowAt(int column) => rows[column] - 1;
}
