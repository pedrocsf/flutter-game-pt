class HazardSpan {
  const HazardSpan({required this.firstColumn, required this.lastColumn});

  final int firstColumn;
  final int lastColumn;

  int get width => lastColumn - firstColumn + 1;

  bool containsColumn(int column) {
    return column >= firstColumn && column <= lastColumn;
  }
}
