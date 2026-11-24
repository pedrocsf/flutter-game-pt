import 'package:moovz_dash/game/procedural/chunk_library.dart';

enum TileKind { empty, solid, platform, slope, hazard }

class TilesetClassParser {
  const TilesetClassParser._();

  static final _tileTag = RegExp(r'<tile\s([^>]*?)/?>');
  static final _idAttribute = RegExp(r'\bid="(\d+)"');
  static final _classAttribute = RegExp(r'\b(?:type|class)="([^"]*)"');

  static Map<int, String> parse(String tileset) {
    final classes = <int, String>{};
    for (final tag in _tileTag.allMatches(tileset)) {
      final attributes = tag.group(1)!;
      final id = _idAttribute.firstMatch(attributes)?.group(1);
      final tileClass = _classAttribute.firstMatch(attributes)?.group(1);
      if (id == null || tileClass == null || tileClass.isEmpty) continue;
      classes[int.parse(id)] = tileClass;
    }
    return classes;
  }
}

typedef SlopeEdges = ({int left, int right});

class SlopeEdgeParser {
  const SlopeEdgeParser._();

  static final _slopeTile = RegExp(
    r'<tile\s[^>]*?\b(?:type|class)="Slope"[^>]*?>([\s\S]*?)</tile>',
  );
  static final _idAttribute = RegExp(r'\bid="(\d+)"');
  static final _tileOpening = RegExp(r'<tile\s[^>]*?>');

  static Map<int, SlopeEdges> parse(String tileset) {
    final edges = <int, SlopeEdges>{};
    for (final match in _slopeTile.allMatches(tileset)) {
      final opening = _tileOpening.firstMatch(match.group(0)!)!.group(0)!;
      final id = _idAttribute.firstMatch(opening)?.group(1);
      final left = _property(match.group(1)!, 'LeftTop');
      final right = _property(match.group(1)!, 'RightTop');
      if (id == null || left == null || right == null) continue;
      edges[int.parse(id)] = (left: left, right: right);
    }
    return edges;
  }

  static int? _property(String body, String name) {
    final pattern = RegExp('name="$name"[^>]*?value="(\\d+)"');
    final value = pattern.firstMatch(body)?.group(1);
    return value == null ? null : int.parse(value);
  }
}

class SolidityTable {
  const SolidityTable(this._classByGid, [this._edgesByGid = const {}]);

  factory SolidityTable.fromTilesets({
    required List<TilesetEntry> tilesets,
    required Map<String, String> sources,
  }) {
    final classByGid = <int, String>{};
    final edgesByGid = <int, SlopeEdges>{};
    for (final tileset in tilesets) {
      final source = sources[tileset.source];
      if (source == null) continue;
      TilesetClassParser.parse(source).forEach((id, tileClass) {
        classByGid[tileset.firstGid + id] = tileClass;
      });
      SlopeEdgeParser.parse(source).forEach((id, edges) {
        edgesByGid[tileset.firstGid + id] = edges;
      });
    }
    return SolidityTable(classByGid, edgesByGid);
  }

  static const empty = SolidityTable({});

  static const _platformClass = 'Platform';
  static const _slopeClass = 'Slope';
  static const _hazardClass = 'Hazard';

  final Map<int, String> _classByGid;
  final Map<int, SlopeEdges> _edgesByGid;

  SlopeEdges? slopeEdgesOf(int gid) {
    return _edgesByGid[ChunkLibrary.stripFlipBits(gid)];
  }

  TileKind kindOf(int gid) {
    final plainGid = ChunkLibrary.stripFlipBits(gid);
    if (plainGid == 0) return TileKind.empty;
    return switch (_classByGid[plainGid]) {
      _platformClass => TileKind.platform,
      _slopeClass => TileKind.slope,
      _hazardClass => TileKind.hazard,
      _ => TileKind.solid,
    };
  }

  bool isSolid(int gid) {
    final kind = kindOf(gid);
    return kind == TileKind.solid || kind == TileKind.hazard;
  }

  bool isHazard(int gid) => kindOf(gid) == TileKind.hazard;

  bool isStandable(int gid) {
    final kind = kindOf(gid);
    return kind != TileKind.empty && kind != TileKind.hazard;
  }

  bool isPlainFloor(int gid) => kindOf(gid) == TileKind.solid;
}
