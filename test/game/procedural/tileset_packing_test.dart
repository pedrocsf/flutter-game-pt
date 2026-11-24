import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/game/procedural/tmx_writer.dart';

import 'procedural_test_support.dart';

const double _atlasSize = 4048;
const double _atlasSpacing = 4;
const int _seedCount = 41;
const int _sectionCount = 3;
const int _pngHeaderWidthOffset = 16;
const int _pngHeaderLength = 24;
const int _flipHorizontal = 0x80000000;
const int _flipVertical = 0x40000000;
const int _flipDiagonal = 0x20000000;
const int _flipBits = _flipHorizontal | _flipVertical | _flipDiagonal;
const int _gidMask = 0x1FFFFFFF;
const String _assetDirectory = 'assets/map/';
const String _animatedPrefix = 'anim';

@immutable
class _Box {
  const _Box(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  @override
  bool operator ==(Object other) {
    return other is _Box &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom;
  }

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

class _BinPacker {
  _BinPacker(double maxX, double maxY) : bins = [_Box(0, 0, maxX, maxY)];

  final List<_Box> bins;

  _Box? pack(double width, double height) {
    _Box? search;
    for (final bin in bins) {
      search = bin;
      if (bin.width >= width && bin.height >= height) break;
    }
    if (search == null || search.width < width || search.height < height) {
      return null;
    }
    bins.remove(search);
    final found = _Box(
      search.left,
      search.top,
      search.left + width,
      search.top + height,
    );
    if (found == search) return found;
    if (found.height != search.height) {
      bins.add(_Box(search.left, found.bottom, search.right, search.bottom));
    }
    if (found.width != search.width) {
      bins.add(_Box(found.right, search.top, search.right, found.bottom));
    }
    bins.sort(_compare);
    return found;
  }

  static int _compare(_Box a, _Box b) {
    final height = a.height - b.height;
    return (height != 0 ? height : a.width - b.width).toInt();
  }
}

List<Point<int>> _readImageSizes(String tilesetSource) {
  final tilesetFile = File('$_assetDirectory$tilesetSource');
  final directory = tilesetFile.parent.path;
  return RegExp(r'<image\s[^>]*?source="([^"]*)"')
      .allMatches(tilesetFile.readAsStringSync())
      .map((match) => _readPngSize('$directory/${match.group(1)}'))
      .toList();
}

Point<int> _readPngSize(String path) {
  final handle = File(path).openSync();
  try {
    final header = handle.readSync(_pngHeaderLength);
    final data = ByteData.sublistView(header);
    return Point(
      data.getUint32(_pngHeaderWidthOffset),
      data.getUint32(_pngHeaderWidthOffset + 4),
    );
  } finally {
    handle.closeSync();
  }
}

bool _fitsInAtlas(List<DeclaredTileset> declared) {
  final packer = _BinPacker(_atlasSize, _atlasSize);
  for (final tileset in declared) {
    if (tileset.source.startsWith(_animatedPrefix)) continue;
    for (final size in _readImageSizes(tileset.source)) {
      final box = packer.pack(size.x + _atlasSpacing, size.y + _atlasSpacing);
      if (box == null) return false;
    }
  }
  return true;
}

String _describe(int seed, GameDifficulty difficulty, int index) {
  return 'seed $seed ${difficulty.name} section $index';
}

@immutable
class _Cell {
  const _Cell(this.source, this.localId, this.flips);

  final String source;
  final int localId;
  final int flips;

  @override
  bool operator ==(Object other) {
    return other is _Cell &&
        other.source == source &&
        other.localId == localId &&
        other.flips == flips;
  }

  @override
  int get hashCode => Object.hash(source, localId, flips);

  @override
  String toString() => '$source#$localId/$flips';
}

_Cell _cellOfLibraryGid(ChunkLibrary library, int gid) {
  final plain = gid & _gidMask;
  final tileset = library.tilesets.firstWhere(
    (entry) => plain >= entry.firstGid && plain <= entry.lastGid,
  );
  return _Cell(tileset.source, plain - tileset.firstGid, gid & _flipBits);
}

_Cell _cellOfWrittenGid(List<DeclaredTileset> declared, int gid) {
  final plain = gid & _gidMask;
  final owner = declared.lastWhere((tileset) => tileset.firstGid <= plain);
  return _Cell(owner.source, plain - owner.firstGid, gid & _flipBits);
}

List<int> _sampleGids(ChunkLibrary library, Random random, int count) {
  const flips = [0, _flipHorizontal, _flipVertical, _flipDiagonal, _flipBits];
  return List.generate(count, (_) {
    final tileset = library.tilesets[random.nextInt(library.tilesets.length)];
    final gid = tileset.firstGid + random.nextInt(tileset.tileCount);
    return gid | flips[random.nextInt(flips.length)];
  });
}

List<List<int>> _toColumns(List<int> gids, int width, int height) {
  return List.generate(
    width,
    (column) => List.generate(height, (row) => gids[column * height + row]),
  );
}

List<int> _readRawCells(String xml, String layerName) {
  final block = RegExp(
    'name="${RegExp.escape(layerName)}"'
    r'[^>]*>\s*<data encoding="csv">\s*([\s\S]*?)</data>',
  ).firstMatch(xml)!.group(1)!;
  final rows = block.trim().split(',\n');
  final cells = <int>[];
  final grid = rows.map((row) => row.split(',').map(int.parse).toList());
  final columnCount = grid.first.length;
  for (var column = 0; column < columnCount; column++) {
    for (final row in grid) {
      cells.add(row[column]);
    }
  }
  return cells;
}

void main() {
  late ChunkLibrary library;
  late ProceduralMapGenerator generator;

  setUpAll(() {
    library = loadLibraryFromDisk();
    generator = ProceduralMapGenerator(library: library);
  });

  test('every packable tileset has a known image size', () {
    for (final tileset in library.tilesets) {
      if (tileset.source.startsWith(_animatedPrefix)) continue;
      expect(tileset.imageSize.hasImage, isTrue, reason: tileset.source);
      final tallest = _readImageSizes(
        tileset.source,
      ).map((s) => s.y).reduce(max);
      expect(tileset.imageSize.height, tallest, reason: tileset.source);
    }
  });

  test('declared tilesets are ordered by image height, animated last', () {
    for (final seed in List.generate(_seedCount, (seed) => seed)) {
      final xml = generator.generateSection(
        seed: seed,
        sectionIndex: 1,
        sectionCount: _sectionCount,
        difficulty: GameDifficulty.medium,
      );
      final declared = readDeclaredTilesets(xml);
      final packable = declared
          .where((t) => !t.source.startsWith(_animatedPrefix))
          .toList();
      final heights = packable.map((t) {
        return library.tilesets
            .firstWhere((entry) => entry.source == t.source)
            .imageSize
            .height;
      }).toList();
      expect(heights, [...heights]..sort((a, b) => b.compareTo(a)));
      expect(
        declared.map((t) => t.source).toList().sublist(packable.length),
        everyElement(startsWith(_animatedPrefix)),
      );
    }
  });

  test('declared tilesets have consecutive non overlapping firstgids', () {
    final xml = generator.generateSection(
      seed: 5,
      sectionIndex: 0,
      sectionCount: _sectionCount,
      difficulty: GameDifficulty.hard,
    );
    final declared = readDeclaredTilesets(xml);
    expect(declared.first.firstGid, 1);
    for (var i = 1; i < declared.length; i++) {
      final previous = library.tilesets.firstWhere(
        (entry) => entry.source == declared[i - 1].source,
      );
      expect(
        declared[i].firstGid,
        declared[i - 1].firstGid + previous.tileCount,
      );
    }
  });

  test('atlas packing in tmx order fits 4048x4048 with spacing 4', () {
    final failures = <String>[];
    for (var seed = 0; seed < _seedCount; seed++) {
      for (final difficulty in GameDifficulty.values) {
        for (var index = 0; index < _sectionCount; index++) {
          final xml = generator.generateSection(
            seed: seed,
            sectionIndex: index,
            sectionCount: _sectionCount,
            difficulty: difficulty,
          );
          if (!_fitsInAtlas(readDeclaredTilesets(xml))) {
            failures.add(_describe(seed, difficulty, index));
          }
        }
      }
    }
    expect(failures, isEmpty);
  });

  test('remapping keeps source, local id and flips of every cell', () {
    final random = Random(7);
    const width = 40;
    const height = 12;
    final tilesets = library.tilesets;
    for (var round = 0; round < 20; round++) {
      final layerGids = _sampleGids(library, random, width * height);
      final objectGids = _sampleGids(library, random, 10);
      final writer =
          TmxWriter(
              width: width,
              height: height,
              tileWidth: library.tileWidth,
              tileHeight: library.tileHeight,
              tilesets: tilesets,
            )
            ..addLayer(
              TmxLayerData(
                name: 'sample',
                columns: _toColumns(layerGids, width, height),
              ),
            )
            ..addObjectGroup(
              TmxObjectGroup(
                name: 'objects',
                objects: [
                  for (final gid in objectGids)
                    ChunkObject(
                      x: 0,
                      y: 0,
                      width: 64,
                      height: 64,
                      gid: gid,
                      type: '',
                      properties: const {},
                    ),
                ],
              ),
            );
      final xml = writer.build();
      final declared = readDeclaredTilesets(xml);
      final written = _readRawCells(xml, 'sample');
      expect(written.length, layerGids.length);
      for (var i = 0; i < written.length; i++) {
        expect(
          _cellOfWrittenGid(declared, written[i]),
          _cellOfLibraryGid(library, layerGids[i]),
        );
      }
      final writtenObjects = RegExp(
        r'<object [^>]*gid="(\d+)"',
      ).allMatches(xml).map((m) => int.parse(m.group(1)!)).toList();
      expect(
        writtenObjects.map((gid) => _cellOfWrittenGid(declared, gid)).toList(),
        objectGids.map((gid) => _cellOfLibraryGid(library, gid)).toList(),
      );
    }
  });

  test('same seed gives the same declaration order', () {
    String declarationOf(int seed) {
      final xml = generator.generateSection(
        seed: seed,
        sectionIndex: 2,
        sectionCount: _sectionCount,
        difficulty: GameDifficulty.hard,
      );
      return readDeclaredTilesets(
        xml,
      ).map((t) => '${t.firstGid}:${t.source}').join(';');
    }

    expect(declarationOf(3), declarationOf(3));
  });
}
