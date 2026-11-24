import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/game/procedural/tmx_writer.dart';

class _PlacedChunk {
  const _PlacedChunk({
    required this.chunk,
    required this.startColumn,
    required this.shift,
  });

  final MapChunk chunk;
  final int startColumn;
  final int shift;

  int get exitHeight => chunk.exitHeight + shift;
}

class GeneratedSection {
  const GeneratedSection({
    required this.xml,
    required this.tunnels,
    required this.lowObstacles,
    this.extendedColumns = 0,
    this.jumpableHazardSpans = const [],
    this.preservedHazardSpans = const [],
    this.route = BottomRoute.empty,
  });

  final String xml;
  final List<Tunnel> tunnels;
  final List<ChunkObject> lowObstacles;
  final int extendedColumns;
  final List<HazardSpan> jumpableHazardSpans;
  final List<HazardSpan> preservedHazardSpans;
  final BottomRoute route;
}

class ProceduralMapGenerator {
  const ProceduralMapGenerator({required this.library});

  final ChunkLibrary library;

  static const minimumSectionWidth = 140;
  static const maxGenerationAttempts = 50;
  static const maxLeadInChunks = 6;
  static const plainChunkDifficulty = 0;
  static const sectionSeedStride = 1000003;
  static const highDifficultyWeight = 3;
  static const highDifficultyThreshold = 2;
  static const biomeOrder = ['A', 'B', 'C'];
  static const _layerNames = [
    'treehouse_back',
    'decorations_terrain',
    'Ground',
    'decorations',
    'water/spikes',
  ];
  static const _frontLayerName = 'treehouse_front';
  static const _filledLayerNames = {'Ground', 'decorations_terrain'};

  @visibleForTesting
  List<MapChunk> chunksOfSection({
    required int seed,
    required int sectionIndex,
    required int sectionCount,
    required GameDifficulty difficulty,
  }) {
    final random = _sectionRandom(seed, sectionIndex);
    final placed = _layoutSection(
      random: random,
      isFirst: sectionIndex == 0,
      isLast: sectionIndex == sectionCount - 1,
      difficulty: difficulty,
    );
    return placed.map((item) => item.chunk).toList();
  }

  String generateSection({
    required int seed,
    required int sectionIndex,
    required int sectionCount,
    required GameDifficulty difficulty,
  }) {
    return buildSection(
      seed: seed,
      sectionIndex: sectionIndex,
      sectionCount: sectionCount,
      difficulty: difficulty,
    ).xml;
  }

  @visibleForTesting
  GeneratedSection buildSection({
    required int seed,
    required int sectionIndex,
    required int sectionCount,
    required GameDifficulty difficulty,
  }) {
    final random = _sectionRandom(seed, sectionIndex);
    final placed = _layoutSection(
      random: random,
      isFirst: sectionIndex == 0,
      isLast: sectionIndex == sectionCount - 1,
      difficulty: difficulty,
    );
    final width = placed.last.startColumn + placed.last.chunk.width;
    final grid = _buildGrid(placed, width, difficulty);
    final jumpableHazardSpans = _jumpableHazardSpans(placed, difficulty);
    final extender = BaseFloorExtender(solidity: library.solidity);
    final firstFloor = extender.extend(
      grid,
      jumpableSpans: jumpableHazardSpans,
    );
    final tunnels = TunnelCarver(
      solidity: library.solidity,
      tiles: library.tunnelTiles,
    ).carve(grid);
    final floor = extender.extend(grid, jumpableSpans: jumpableHazardSpans);
    tunnels.addAll(
      BuriedPathCarver(
        solidity: library.solidity,
        tiles: library.tunnelTiles,
      ).carve(grid, floor.route),
    );
    RouteClearance(solidity: library.solidity).clear(grid, floor.route);
    final objects = _collectObjects(
      placed: placed,
      random: random,
      difficulty: difficulty,
      addSpawn: sectionIndex > 0,
    );
    final lowObstacles = _placeLowObstacles(
      grid: grid,
      tunnels: tunnels,
      objects: objects,
      difficulty: difficulty,
      random: random,
    );
    objects['enemies']!.addAll(lowObstacles);
    objects['items'] = ExtraLifePlacer(tileSize: library.tileWidth.toDouble())
        .place(
          items: objects['items']!,
          sectionWidth: width,
          difficulty: difficulty,
          random: random,
        );
    final biome = biomeOrder[sectionIndex % biomeOrder.length];
    return GeneratedSection(
      xml: _write(grid: grid, biome: biome, objects: objects),
      tunnels: tunnels,
      lowObstacles: lowObstacles,
      extendedColumns: firstFloor.extendedColumns + floor.extendedColumns,
      jumpableHazardSpans: jumpableHazardSpans,
      preservedHazardSpans: floor.preservedSpans,
      route: floor.route,
    );
  }

  List<HazardSpan> _jumpableHazardSpans(
    List<_PlacedChunk> placed,
    GameDifficulty difficulty,
  ) {
    return [
      for (final item in placed)
        for (final strip in item.chunk.hazardStrips)
          if (strip.isJumpable(difficulty.storageKey))
            HazardSpan(
              firstColumn: item.startColumn + strip.columns.reduce(min),
              lastColumn: item.startColumn + strip.columns.reduce(max),
            ),
    ];
  }

  List<ChunkObject> _placeLowObstacles({
    required SectionGrid grid,
    required List<Tunnel> tunnels,
    required Map<String, List<ChunkObject>> objects,
    required GameDifficulty difficulty,
    required Random random,
  }) {
    return LowObstaclePlacer(
      solidity: library.solidity,
      enemyGid: library.enemyGid,
      tileSize: library.tileWidth.toDouble(),
    ).place(
      grid: grid,
      tunnels: tunnels,
      objects: objects,
      difficulty: difficulty,
      random: random,
    );
  }

  static Random _sectionRandom(int seed, int sectionIndex) {
    return Random(seed * sectionSeedStride + sectionIndex);
  }

  List<_PlacedChunk> _layoutSection({
    required Random random,
    required bool isFirst,
    required bool isLast,
    required GameDifficulty difficulty,
  }) {
    for (var attempt = 0; attempt < maxGenerationAttempts; attempt++) {
      final placed = _tryLayout(
        random: random,
        isFirst: isFirst,
        isLast: isLast,
        difficulty: difficulty,
      );
      if (placed != null) return placed;
    }
    throw StateError('Unable to generate a valid map section');
  }

  List<_PlacedChunk>? _tryLayout({
    required Random random,
    required bool isFirst,
    required bool isLast,
    required GameDifficulty difficulty,
  }) {
    final placed = <_PlacedChunk>[_openingChunk(random, isFirst, difficulty)];
    var width = placed.first.chunk.width;
    while (width < minimumSectionWidth) {
      final next = _nextBodyChunk(placed, width, random, difficulty);
      if (next == null) return null;
      placed.add(next);
      width += next.chunk.width;
    }
    final closing = _closeSection(placed, width, random, isLast, difficulty);
    if (closing == null) return null;
    return placed..add(closing);
  }

  _PlacedChunk? _closeSection(
    List<_PlacedChunk> placed,
    int width,
    Random random,
    bool isLast,
    GameDifficulty difficulty,
  ) {
    var currentWidth = width;
    for (var extra = 0; extra <= maxLeadInChunks; extra++) {
      final closing = _closingChunk(
        placed.last,
        currentWidth,
        random,
        isLast,
        difficulty,
      );
      if (closing != null) return closing;
      final leadIn = _leadInChunk(
        placed.last,
        currentWidth,
        random,
        difficulty,
      );
      if (leadIn == null) return null;
      placed.add(leadIn);
      currentWidth += leadIn.chunk.width;
    }
    return null;
  }

  _PlacedChunk? _leadInChunk(
    _PlacedChunk previous,
    int width,
    Random random,
    GameDifficulty difficulty,
  ) {
    final candidates = library
        .chunksOfKind(ChunkKind.normal)
        .where((chunk) => _isUsable(chunk, difficulty))
        .where((chunk) => chunk.id != previous.chunk.id)
        .where((chunk) => !_repeatsPlainChunk(chunk, previous))
        .where((chunk) => _fits(chunk, previous))
        .where((chunk) => chunk.exitHeight < chunk.entryHeight)
        .toList();
    if (candidates.isEmpty) return null;
    return _place(_pick(candidates, random), previous, width);
  }

  _PlacedChunk _openingChunk(
    Random random,
    bool isFirst,
    GameDifficulty difficulty,
  ) {
    final start = library.chunksOfKind(ChunkKind.start).first;
    if (isFirst) return _PlacedChunk(chunk: start, startColumn: 0, shift: 0);
    final runouts = _preferUsable(
      library.chunksOfKind(ChunkKind.runout),
      difficulty,
    );
    final fitting = runouts.where((chunk) {
      return chunk.fitsWithShift(
        shift: start.entryHeight - chunk.entryHeight,
        mapHeight: library.mapHeight,
      );
    }).toList();
    final runout = _pick(fitting.isEmpty ? runouts : fitting, random);
    return _PlacedChunk(
      chunk: runout,
      startColumn: 0,
      shift: start.entryHeight - runout.entryHeight,
    );
  }

  _PlacedChunk? _nextBodyChunk(
    List<_PlacedChunk> placed,
    int width,
    Random random,
    GameDifficulty difficulty,
  ) {
    final previous = placed.last;
    final candidates = library
        .chunksOfKind(ChunkKind.normal)
        .where((chunk) => chunk.difficulty <= difficulty.maxChunkDifficulty)
        .where((chunk) => _isUsable(chunk, difficulty))
        .where((chunk) => chunk.id != previous.chunk.id)
        .where((chunk) => !_repeatsPlainChunk(chunk, previous))
        .where((chunk) => _fits(chunk, previous))
        .toList();
    if (candidates.isEmpty) return null;
    return _place(
      _pickWeighted(candidates, random, difficulty),
      previous,
      width,
    );
  }

  bool _repeatsPlainChunk(MapChunk chunk, _PlacedChunk previous) {
    return _isPlainChunk(chunk) && _isPlainChunk(previous.chunk);
  }

  bool _isPlainChunk(MapChunk chunk) {
    return chunk.kind == ChunkKind.normal &&
        chunk.difficulty == plainChunkDifficulty;
  }

  _PlacedChunk? _closingChunk(
    _PlacedChunk previous,
    int width,
    Random random,
    bool isLast,
    GameDifficulty difficulty,
  ) {
    final kind = isLast ? ChunkKind.end : ChunkKind.runout;
    final fitting = library
        .chunksOfKind(kind)
        .where((chunk) => _fits(chunk, previous))
        .toList();
    final candidates = fitting
        .where((chunk) => _isUsable(chunk, difficulty))
        .toList();
    if (candidates.isNotEmpty) {
      return _place(_pick(candidates, random), previous, width);
    }
    if (!isLast || fitting.isEmpty) return null;
    final chosen = _pick(fitting, random);
    _reportUnusableEnd(chosen, difficulty);
    return _place(chosen, previous, width);
  }

  bool _isUsable(MapChunk chunk, GameDifficulty difficulty) {
    return chunk.isUsable(difficulty.storageKey);
  }

  List<MapChunk> _preferUsable(
    List<MapChunk> chunks,
    GameDifficulty difficulty,
  ) {
    final usable = chunks
        .where((chunk) => _isUsable(chunk, difficulty))
        .toList();
    return usable.isEmpty ? chunks : usable;
  }

  void _reportUnusableEnd(MapChunk chunk, GameDifficulty difficulty) {
    debugPrint(
      'Procedural map: end chunk ${chunk.id} is not linear '
      'on ${difficulty.storageKey}',
    );
  }

  bool _fits(MapChunk chunk, _PlacedChunk previous) {
    final shift = _shiftAfter(previous, chunk);
    return chunk.fitsWithShift(shift: shift, mapHeight: library.mapHeight) &&
        _joinsSmoothly(chunk, shift, previous);
  }

  bool _joinsSmoothly(MapChunk chunk, int shift, _PlacedChunk previous) {
    final exitEdges = _partialSlopeEdges(
      previous.chunk,
      column: previous.chunk.width - 1,
      shift: previous.shift,
      useRightEdge: true,
    );
    final entryEdges = _partialSlopeEdges(
      chunk,
      column: 0,
      shift: shift,
      useRightEdge: false,
    );
    return setEquals(exitEdges, entryEdges);
  }

  Set<int> _partialSlopeEdges(
    MapChunk chunk, {
    required int column,
    required int shift,
    required bool useRightEdge,
  }) {
    final ground = chunk.layers[MapChunk.groundLayerName];
    if (ground == null || column >= ground.length) return const {};
    final tileHeight = library.tileHeight;
    final edges = <int>{};
    for (var row = 0; row < ground[column].length; row++) {
      final slope = library.solidity.slopeEdgesOf(ground[column][row]);
      if (slope == null) continue;
      final edgeHeight = useRightEdge ? slope.right : slope.left;
      if (edgeHeight <= 0 || edgeHeight >= tileHeight) continue;
      edges.add((row + shift + 1) * tileHeight - edgeHeight);
    }
    return edges;
  }

  int _shiftAfter(_PlacedChunk previous, MapChunk chunk) {
    return previous.exitHeight - chunk.entryHeight;
  }

  _PlacedChunk _place(MapChunk chunk, _PlacedChunk previous, int width) {
    return _PlacedChunk(
      chunk: chunk,
      startColumn: width,
      shift: _shiftAfter(previous, chunk),
    );
  }

  MapChunk _pick(List<MapChunk> chunks, Random random) {
    return chunks[random.nextInt(chunks.length)];
  }

  MapChunk _pickWeighted(
    List<MapChunk> chunks,
    Random random,
    GameDifficulty difficulty,
  ) {
    final weights = chunks.map((chunk) => _weight(chunk, difficulty)).toList();
    var roll = random.nextInt(weights.reduce((a, b) => a + b));
    for (var index = 0; index < chunks.length; index++) {
      roll -= weights[index];
      if (roll < 0) return chunks[index];
    }
    return chunks.last;
  }

  int _weight(MapChunk chunk, GameDifficulty difficulty) {
    final isHard = difficulty == GameDifficulty.hard;
    if (isHard && chunk.difficulty >= highDifficultyThreshold) {
      return highDifficultyWeight;
    }
    return 1;
  }

  Map<String, List<ChunkObject>> _collectObjects({
    required List<_PlacedChunk> placed,
    required Random random,
    required GameDifficulty difficulty,
    required bool addSpawn,
  }) {
    final collected = {
      'items': <ChunkObject>[],
      'enemies': <ChunkObject>[],
      'spawn': <ChunkObject>[],
      'respawn': <ChunkObject>[],
    };
    for (final item in placed) {
      final objects = item.chunk.objects;
      collected['items']!.addAll(_moveAll(objects.items, item));
      collected['respawn']!.addAll(_moveAll(objects.respawn, item));
      collected['spawn']!.addAll(_moveAll(objects.spawn, item));
      for (final enemy in _moveAll(objects.enemies, item)) {
        if (random.nextDouble() < difficulty.enemyKeepRatio) {
          collected['enemies']!.add(enemy);
        }
      }
    }
    if (addSpawn) {
      collected['spawn']!.addAll(
        library.chunksOfKind(ChunkKind.start).first.objects.spawn,
      );
    }
    return collected;
  }

  List<ChunkObject> _moveAll(List<ChunkObject> objects, _PlacedChunk placed) {
    final dx = placed.startColumn * library.tileWidth.toDouble();
    final dy = placed.shift * library.tileHeight.toDouble();
    return objects.map((o) => o.moved(dx: dx, dy: dy)).toList();
  }

  String _write({
    required SectionGrid grid,
    required String biome,
    required Map<String, List<ChunkObject>> objects,
  }) {
    final writer = TmxWriter(
      width: grid.width,
      height: library.mapHeight,
      tileWidth: library.tileWidth,
      tileHeight: library.tileHeight,
      tilesets: library.tilesets,
    );
    _writeBackground(writer, library.backgroundFor(biome), grid.width);
    for (final name in _layerNames) {
      writer.addLayer(grid.toLayerData(name));
    }
    for (final name in ['items', 'enemies', 'spawn', 'respawn']) {
      writer.addObjectGroup(
        TmxObjectGroup(name: name, objects: objects[name]!),
      );
    }
    writer.addLayer(grid.toLayerData(_frontLayerName));
    return writer.build();
  }

  void _writeBackground(TmxWriter writer, Background background, int width) {
    for (final group in background.groups) {
      writer.addGroup(
        name: group.name,
        offsetX: group.offsetX,
        offsetY: group.offsetY,
        layers: group.layers.map((l) => _backgroundLayer(l, width)).toList(),
      );
    }
    for (final layer in background.layers) {
      writer.addLayer(_backgroundLayer(layer, width));
    }
  }

  TmxLayerData _backgroundLayer(BackgroundLayer layer, int width) {
    final source = layer.columns;
    return TmxLayerData(
      name: layer.name,
      offsetX: layer.offsetX,
      offsetY: layer.offsetY,
      parallaxX: layer.parallaxX,
      parallaxY: layer.parallaxY,
      opacity: layer.opacity,
      columns: List.generate(
        width,
        (column) =>
            source.isEmpty ? _emptyColumn() : source[column % source.length],
      ),
    );
  }

  List<int> _emptyColumn() => List.filled(library.mapHeight, 0);

  SectionGrid _buildGrid(
    List<_PlacedChunk> placed,
    int width,
    GameDifficulty difficulty,
  ) {
    return SectionGrid(
      width: width,
      height: library.mapHeight,
      layers: {
        for (final name in [..._layerNames, _frontLayerName])
          name: _gameLayer(name, placed, width, difficulty),
      },
    );
  }

  List<List<int>> _gameLayer(
    String name,
    List<_PlacedChunk> placed,
    int width,
    GameDifficulty difficulty,
  ) {
    final columns = List.generate(width, (_) => _emptyColumn());
    for (final item in placed) {
      final source = item.chunk.layersForLevel(difficulty.storageKey)[name];
      if (source == null) continue;
      for (var index = 0; index < source.length; index++) {
        _copyColumn(
          source[index],
          columns[item.startColumn + index],
          item.shift,
          fillBelow: _filledLayerNames.contains(name),
        );
      }
    }
    return columns;
  }

  void _copyColumn(
    List<int> source,
    List<int> target,
    int shift, {
    required bool fillBelow,
  }) {
    var lastFilledRow = -1;
    for (var row = 0; row < source.length; row++) {
      final targetRow = row + shift;
      if (source[row] == 0 || targetRow >= target.length) continue;
      target[targetRow] = source[row];
      if (targetRow > lastFilledRow) lastFilledRow = targetRow;
    }
    if (fillBelow && shift < 0) {
      _fillBelow(target, lastFilledRow, source.last);
    }
  }

  void _fillBelow(List<int> target, int lastFilledRow, int tile) {
    if (tile == 0 || lastFilledRow < 0) return;
    for (var row = lastFilledRow + 1; row < target.length; row++) {
      if (target[row] == 0) target[row] = tile;
    }
  }
}
