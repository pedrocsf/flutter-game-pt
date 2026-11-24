import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:moovz_dash/game/procedural/hazard_strip.dart';
import 'package:moovz_dash/game/procedural/solidity_table.dart';
import 'package:moovz_dash/game/procedural/tileset_image_size.dart';
import 'package:moovz_dash/game/procedural/tunnel_tiles.dart';

enum ChunkKind {
  start,
  end,
  runout,
  normal;

  static ChunkKind fromName(String name) {
    return ChunkKind.values.firstWhere((kind) => kind.name == name);
  }
}

class TilesetEntry {
  const TilesetEntry({
    required this.source,
    required this.firstGid,
    required this.tileCount,
    this.imageSize = const TilesetImageSize.none(),
  });

  factory TilesetEntry.fromJson(Map<String, dynamic> json) {
    return TilesetEntry(
      source: json['source'] as String,
      firstGid: json['firstgid'] as int,
      tileCount: json['tilecount'] as int,
    );
  }

  final String source;
  final int firstGid;
  final int tileCount;
  final TilesetImageSize imageSize;

  int get lastGid => firstGid + tileCount - 1;

  TilesetEntry withImageSize(TilesetImageSize size) {
    return TilesetEntry(
      source: source,
      firstGid: firstGid,
      tileCount: tileCount,
      imageSize: size,
    );
  }
}

class ChunkObject {
  const ChunkObject({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.gid,
    required this.type,
    required this.properties,
  });

  factory ChunkObject.fromJson(Map<String, dynamic> json) {
    return ChunkObject(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      gid: json['gid'] as int,
      type: json['type'] as String? ?? '',
      properties: Map<String, Object>.from(
        (json['properties'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }

  final double x;
  final double y;
  final double width;
  final double height;
  final int gid;
  final String type;
  final Map<String, Object> properties;

  ChunkObject moved({required double dx, required double dy}) {
    return ChunkObject(
      x: x + dx,
      y: y + dy,
      width: width,
      height: height,
      gid: gid,
      type: type,
      properties: properties,
    );
  }
}

class ChunkObjects {
  const ChunkObjects({
    required this.items,
    required this.enemies,
    required this.respawn,
    required this.spawn,
  });

  factory ChunkObjects.fromJson(Map<String, dynamic> json) {
    List<ChunkObject> read(String key) {
      final list = (json[key] as List<dynamic>?) ?? const [];
      return list
          .map((e) => ChunkObject.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return ChunkObjects(
      items: read('items'),
      enemies: read('enemies'),
      respawn: read('respawn'),
      spawn: read('spawn'),
    );
  }

  final List<ChunkObject> items;
  final List<ChunkObject> enemies;
  final List<ChunkObject> respawn;
  final List<ChunkObject> spawn;
}

List<List<int>> _readColumns(dynamic json) {
  return (json as List<dynamic>)
      .map((column) => List<int>.from(column as List<dynamic>))
      .toList();
}

class MapChunk {
  MapChunk({
    required this.id,
    required this.biome,
    required this.kind,
    required this.width,
    required this.entryHeight,
    required this.exitHeight,
    required this.difficulty,
    required this.layers,
    required this.objects,
    this.traversable = const {},
    this.linear = const {},
    this.hazardStrips = const [],
  }) {
    var first = -1;
    var last = -1;
    for (final columns in layers.values) {
      for (final column in columns) {
        for (var row = 0; row < column.length; row++) {
          if (column[row] == 0) continue;
          if (first == -1 || row < first) first = row;
          if (row > last) last = row;
        }
      }
    }
    firstFilledRow = first;
    lastFilledRow = last;
    lastSpikeRow = _lastFilledRowOf(layers[spikesLayerName]);
    deepestGroundTopRow = _deepestColumnTop(layers[groundLayerName]);
  }

  factory MapChunk.fromJson(Map<String, dynamic> json) {
    final rawLayers = json['layers'] as Map<String, dynamic>;
    return MapChunk(
      id: json['id'] as String,
      biome: json['biome'] as String,
      kind: ChunkKind.fromName(json['kind'] as String),
      width: json['width'] as int,
      entryHeight: json['entryHeight'] as int,
      exitHeight: json['exitHeight'] as int,
      difficulty: json['difficulty'] as int,
      layers: rawLayers.map(
        (name, value) => MapEntry(name, _readColumns(value)),
      ),
      objects: ChunkObjects.fromJson(json['objects'] as Map<String, dynamic>),
      traversable: _readFlags(json['traversable']),
      linear: _readFlags(json['linear']),
      hazardStrips: _readStrips(json['hazardStrips']),
    );
  }

  static int _lastFilledRowOf(List<List<int>>? columns) {
    var last = -1;
    for (final column in columns ?? const <List<int>>[]) {
      for (var row = column.length - 1; row > last; row--) {
        if (column[row] != 0) last = row;
      }
    }
    return last;
  }

  static int _deepestColumnTop(List<List<int>>? columns) {
    var deepest = -1;
    for (final column in columns ?? const <List<int>>[]) {
      final top = column.indexWhere((tile) => tile != 0);
      if (top > deepest) deepest = top;
    }
    return deepest;
  }

  static Map<String, bool> _readFlags(dynamic json) {
    if (json == null) return const {};
    return (json as Map<String, dynamic>).map(
      (level, value) => MapEntry(level, value as bool),
    );
  }

  static List<HazardStrip> _readStrips(dynamic json) {
    return ((json as List<dynamic>?) ?? const [])
        .map((e) => HazardStrip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  final String id;
  final String biome;
  final ChunkKind kind;
  final int width;
  final int entryHeight;
  final int exitHeight;
  final int difficulty;
  final Map<String, List<List<int>>> layers;
  final ChunkObjects objects;
  final Map<String, bool> traversable;
  final Map<String, bool> linear;
  final List<HazardStrip> hazardStrips;
  final Map<String, Map<String, List<List<int>>>> _levelLayers = {};
  late final int firstFilledRow;
  late final int lastFilledRow;
  late final int lastSpikeRow;
  late final int deepestGroundTopRow;

  static const minimumGroundRows = 2;
  static const spikesLayerName = 'water/spikes';
  static const groundLayerName = 'Ground';

  bool isTraversable(String level) => traversable[level] ?? true;

  bool isLinear(String level) => linear[level] ?? true;

  bool isUsable(String level) => isTraversable(level) && isLinear(level);

  Map<String, List<List<int>>> layersForLevel(String level) {
    return _levelLayers.putIfAbsent(level, () => _resolveLayers(level));
  }

  Map<String, List<List<int>>> _resolveLayers(String level) {
    final strips = hazardStrips.where((strip) => !strip.isJumpable(level));
    if (strips.isEmpty) return layers;
    final resolved = Map<String, List<List<int>>>.from(layers);
    for (final strip in strips) {
      _pave(resolved, strip);
    }
    return resolved;
  }

  void _pave(Map<String, List<List<int>>> resolved, HazardStrip strip) {
    final ground = resolved[groundLayerName];
    final spikes = resolved[spikesLayerName];
    if (ground != null) {
      resolved[groundLayerName] = _withCells(ground, strip.safeGround);
    }
    if (spikes != null) {
      resolved[spikesLayerName] = _withClearedRows(spikes, strip.clearSpikes);
    }
  }

  static List<List<int>> _withCells(
    List<List<int>> columns,
    Map<int, Map<int, int>> cells,
  ) {
    final result = List<List<int>>.of(columns);
    cells.forEach((column, rows) {
      final copy = List<int>.of(result[column]);
      rows.forEach((row, gid) => copy[row] = gid);
      result[column] = copy;
    });
    return result;
  }

  static List<List<int>> _withClearedRows(
    List<List<int>> columns,
    Map<int, List<int>> cleared,
  ) {
    final result = List<List<int>>.of(columns);
    cleared.forEach((column, rows) {
      final copy = List<int>.of(result[column]);
      for (final row in rows) {
        copy[row] = 0;
      }
      result[column] = copy;
    });
    return result;
  }

  bool fitsWithShift({required int shift, required int mapHeight}) {
    if (firstFilledRow == -1) return true;
    final lowestFloor = max(entryHeight, exitHeight) + shift;
    return firstFilledRow + shift >= 0 &&
        lowestFloor <= mapHeight - minimumGroundRows &&
        lastSpikeRow + shift < mapHeight &&
        deepestGroundTopRow + shift < mapHeight;
  }
}

class BackgroundLayer {
  const BackgroundLayer({
    required this.name,
    required this.offsetX,
    required this.offsetY,
    required this.parallaxX,
    required this.parallaxY,
    required this.opacity,
    required this.columns,
  });

  factory BackgroundLayer.fromJson(Map<String, dynamic> json) {
    return BackgroundLayer(
      name: json['name'] as String,
      offsetX: (json['offsetx'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsety'] as num?)?.toDouble() ?? 0,
      parallaxX: (json['parallaxx'] as num?)?.toDouble() ?? 1,
      parallaxY: (json['parallaxy'] as num?)?.toDouble() ?? 1,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
      columns: _readColumns(json['columns']),
    );
  }

  final String name;
  final double offsetX;
  final double offsetY;
  final double parallaxX;
  final double parallaxY;
  final double opacity;
  final List<List<int>> columns;
}

class BackgroundGroup {
  const BackgroundGroup({
    required this.name,
    required this.offsetX,
    required this.offsetY,
    required this.layers,
  });

  factory BackgroundGroup.fromJson(Map<String, dynamic> json) {
    return BackgroundGroup(
      name: json['name'] as String,
      offsetX: (json['offsetx'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsety'] as num?)?.toDouble() ?? 0,
      layers: (json['layers'] as List<dynamic>)
          .map((e) => BackgroundLayer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String name;
  final double offsetX;
  final double offsetY;
  final List<BackgroundLayer> layers;
}

class Background {
  const Background({
    required this.width,
    required this.groups,
    required this.layers,
  });

  factory Background.fromJson(Map<String, dynamic> json) {
    List<T> read<T>(String key, T Function(Map<String, dynamic>) parse) {
      return ((json[key] as List<dynamic>?) ?? const [])
          .map((e) => parse(e as Map<String, dynamic>))
          .toList();
    }

    return Background(
      width: json['width'] as int,
      groups: read('groups', BackgroundGroup.fromJson),
      layers: read('layers', BackgroundLayer.fromJson),
    );
  }

  final int width;
  final List<BackgroundGroup> groups;
  final List<BackgroundLayer> layers;
}

class ChunkLibrary {
  ChunkLibrary({
    required this.tileWidth,
    required this.tileHeight,
    required this.mapHeight,
    required this.tilesets,
    required this.enemyGid,
    required this.backgrounds,
    required this.chunks,
    this.solidity = SolidityTable.empty,
  });

  factory ChunkLibrary.fromJson(
    Map<String, dynamic> json, {
    SolidityTable solidity = SolidityTable.empty,
    Map<String, TilesetImageSize> imageSizes = const {},
  }) {
    return ChunkLibrary(
      tileWidth: json['tileWidth'] as int,
      tileHeight: json['tileHeight'] as int,
      mapHeight: json['mapHeight'] as int,
      enemyGid: json['enemyGid'] as int,
      solidity: solidity,
      tilesets: _withImageSizes(
        _withTunnelTileset(_readTilesets(json)),
        imageSizes,
      ),
      backgrounds: (json['backgrounds'] as Map<String, dynamic>).map(
        (biome, value) =>
            MapEntry(biome, Background.fromJson(value as Map<String, dynamic>)),
      ),
      chunks: (json['chunks'] as List<dynamic>)
          .map((e) => MapChunk.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory ChunkLibrary.fromSources(
    Map<String, dynamic> json,
    Map<String, String> sources,
  ) {
    final classifiedSources = {
      for (final entry in sources.entries)
        if (entry.key.startsWith(classifiedSourcePrefix) &&
            entry.key != TunnelTiles.source)
          entry.key: entry.value,
    };
    final solidity = SolidityTable.fromTilesets(
      tilesets: _readTilesets(json),
      sources: classifiedSources,
    );
    final imageSizes = sources.map(
      (key, value) => MapEntry(key, TilesetImageSize.parse(value)),
    );
    return ChunkLibrary.fromJson(
      json,
      solidity: solidity,
      imageSizes: imageSizes,
    );
  }

  static const assetPath = 'assets/map/procedural/chunks.json';

  static const tilesetDirectory = 'assets/map/';
  static const classifiedSourcePrefix = 'tiles/';
  static const animatedSourcePrefix = 'anim/';

  static Future<ChunkLibrary> load(AssetBundle bundle) async {
    final source = await bundle.loadString(assetPath);
    final json = jsonDecode(source) as Map<String, dynamic>;
    final sources = await _loadTilesetSources(bundle, tilesetSourcesOf(json));
    return ChunkLibrary.fromSources(json, sources);
  }

  static List<String> tilesetSourcesOf(Map<String, dynamic> json) {
    final sources = _readTilesets(json)
        .map((tileset) => tileset.source)
        .where((source) => !source.startsWith(animatedSourcePrefix))
        .toSet();
    return [...sources, TunnelTiles.source];
  }

  static List<TilesetEntry> _readTilesets(Map<String, dynamic> json) {
    return (json['tilesets'] as List<dynamic>)
        .map((e) => TilesetEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<TilesetEntry> _withTunnelTileset(List<TilesetEntry> tilesets) {
    if (tilesets.any((tileset) => tileset.source == TunnelTiles.source)) {
      return tilesets;
    }
    final lastGid = tilesets.map((t) => t.lastGid).reduce(max);
    return [
      ...tilesets,
      TilesetEntry(
        source: TunnelTiles.source,
        firstGid: lastGid + 1,
        tileCount: TunnelTiles.tileCount,
      ),
    ];
  }

  static List<TilesetEntry> _withImageSizes(
    List<TilesetEntry> tilesets,
    Map<String, TilesetImageSize> imageSizes,
  ) {
    return tilesets
        .map(
          (tileset) => tileset.withImageSize(
            imageSizes[tileset.source] ?? const TilesetImageSize.none(),
          ),
        )
        .toList();
  }

  static Future<Map<String, String>> _loadTilesetSources(
    AssetBundle bundle,
    List<String> sources,
  ) async {
    final contents = await Future.wait(
      sources.map((source) => bundle.loadString('$tilesetDirectory$source')),
    );
    return Map.fromIterables(sources, contents);
  }

  final int tileWidth;
  final int tileHeight;
  final int mapHeight;
  final int enemyGid;
  final List<TilesetEntry> tilesets;
  final Map<String, Background> backgrounds;
  final List<MapChunk> chunks;
  final SolidityTable solidity;

  static const _flipMask = 0x1FFFFFFF;

  TunnelTiles get tunnelTiles {
    final tileset = tilesets.firstWhere(
      (entry) => entry.source == TunnelTiles.source,
    );
    return TunnelTiles(firstGid: tileset.firstGid);
  }

  int get maxGid =>
      tilesets.map((t) => t.lastGid).reduce((a, b) => a > b ? a : b);

  static int stripFlipBits(int gid) => gid & _flipMask;

  List<MapChunk> chunksOfKind(ChunkKind kind) {
    return chunks.where((chunk) => chunk.kind == kind).toList();
  }

  Background backgroundFor(String biome) {
    return backgrounds[biome] ?? backgrounds.values.first;
  }
}
