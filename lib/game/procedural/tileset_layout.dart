import 'package:moovz_dash/game/procedural/chunk_library.dart';

class TilesetPlacement {
  const TilesetPlacement({
    required this.source,
    required this.originalFirstGid,
    required this.firstGid,
    required this.tileCount,
  });

  final String source;
  final int originalFirstGid;
  final int firstGid;
  final int tileCount;
}

class TilesetLayout {
  TilesetLayout._(this.placements, this._newGidByOldGid);

  factory TilesetLayout.arrange(List<TilesetEntry> declared) {
    final ordered = orderForPacking(declared);
    final placements = <TilesetPlacement>[];
    var nextFirstGid = _firstGidStart;
    for (final tileset in ordered) {
      placements.add(
        TilesetPlacement(
          source: tileset.source,
          originalFirstGid: tileset.firstGid,
          firstGid: nextFirstGid,
          tileCount: tileset.tileCount,
        ),
      );
      nextFirstGid += tileset.tileCount;
    }
    return TilesetLayout._(placements, _buildGidTable(placements));
  }

  static const _firstGidStart = 1;
  static const _flipMask = 0x1FFFFFFF;
  static const _unmapped = -1;

  final List<TilesetPlacement> placements;
  final List<int> _newGidByOldGid;

  static List<TilesetEntry> orderForPacking(List<TilesetEntry> tilesets) {
    final packable = tilesets.where(_isPackable).toList()
      ..sort(_compareForPacking);
    final trailing = tilesets.where((tileset) => !_isPackable(tileset));
    return [...packable, ...trailing];
  }

  int remap(int gid) {
    if (gid == 0) return 0;
    final plainGid = gid & _flipMask;
    final flipBits = gid & ~_flipMask;
    final newGid = plainGid < _newGidByOldGid.length
        ? _newGidByOldGid[plainGid]
        : _unmapped;
    if (newGid == _unmapped) {
      throw StateError('gid $plainGid does not belong to a declared tileset');
    }
    return flipBits | newGid;
  }

  static bool _isPackable(TilesetEntry tileset) {
    return !tileset.source.startsWith(ChunkLibrary.animatedSourcePrefix) &&
        tileset.imageSize.hasImage;
  }

  static int _compareForPacking(TilesetEntry a, TilesetEntry b) {
    final byHeight = b.imageSize.height.compareTo(a.imageSize.height);
    if (byHeight != 0) return byHeight;
    final byWidth = b.imageSize.width.compareTo(a.imageSize.width);
    if (byWidth != 0) return byWidth;
    return a.firstGid.compareTo(b.firstGid);
  }

  static List<int> _buildGidTable(List<TilesetPlacement> placements) {
    var highestOriginalGid = 0;
    for (final placement in placements) {
      final last = placement.originalFirstGid + placement.tileCount - 1;
      if (last > highestOriginalGid) highestOriginalGid = last;
    }
    final table = List<int>.filled(highestOriginalGid + 1, _unmapped);
    for (final placement in placements) {
      for (var id = 0; id < placement.tileCount; id++) {
        table[placement.originalFirstGid + id] = placement.firstGid + id;
      }
    }
    return table;
  }
}
