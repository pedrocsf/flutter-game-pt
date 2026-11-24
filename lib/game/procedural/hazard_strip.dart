class HazardStrip {
  const HazardStrip({
    required this.columns,
    required this.safeGround,
    required this.clearSpikes,
    required this.jumpable,
  });

  factory HazardStrip.fromJson(Map<String, dynamic> json) {
    return HazardStrip(
      columns: List<int>.from(json['columns'] as List<dynamic>),
      safeGround: _readSafeGround(json['safeGround']),
      clearSpikes: _readClearSpikes(json['clearSpikes']),
      jumpable: _readJumpable(json['jumpable']),
    );
  }

  final List<int> columns;
  final Map<int, Map<int, int>> safeGround;
  final Map<int, List<int>> clearSpikes;
  final Map<String, bool> jumpable;

  bool isJumpable(String level) => jumpable[level] ?? true;

  int get width => columns.length;

  static Map<int, Map<int, int>> _readSafeGround(dynamic json) {
    final columns = (json as Map<String, dynamic>?) ?? const {};
    return columns.map((column, cells) {
      final rows = cells as Map<String, dynamic>;
      return MapEntry(
        int.parse(column),
        rows.map((row, gid) => MapEntry(int.parse(row), gid as int)),
      );
    });
  }

  static Map<int, List<int>> _readClearSpikes(dynamic json) {
    final columns = (json as Map<String, dynamic>?) ?? const {};
    return columns.map(
      (column, rows) =>
          MapEntry(int.parse(column), List<int>.from(rows as List<dynamic>)),
    );
  }

  static Map<String, bool> _readJumpable(dynamic json) {
    final levels = (json as Map<String, dynamic>?) ?? const {};
    return levels.map((level, value) => MapEntry(level, value as bool));
  }
}
