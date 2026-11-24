enum TunnelKind { wallCut, buriedPath }

class Tunnel {
  const Tunnel({
    required this.firstColumn,
    required this.lastColumn,
    required this.standRow,
    this.kind = TunnelKind.wallCut,
    this.startsPath = true,
    this.endsPath = true,
    this.explicitPathFirstColumn,
  });

  static const clearHeight = 4;

  final int firstColumn;
  final int lastColumn;
  final int standRow;
  final TunnelKind kind;
  final bool startsPath;
  final bool endsPath;
  final int? explicitPathFirstColumn;

  int get pathFirstColumn => explicitPathFirstColumn ?? firstColumn;

  int get length => lastColumn - firstColumn + 1;

  int get roofRow => standRow - clearHeight;

  int get topRow => standRow - clearHeight + 1;

  int get floorRow => standRow + 1;

  bool containsColumn(int column) {
    return column >= firstColumn && column <= lastColumn;
  }
}
