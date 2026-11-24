import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';

import 'procedural_test_support.dart';

void main() {
  late ChunkLibrary library;
  late ProceduralMapGenerator generator;

  const seeds = [1, 7, 42, 1234, 99999];

  String generate(
    int seed,
    GameDifficulty difficulty, {
    int index = 0,
    int count = 3,
  }) {
    return generator.generateSection(
      seed: seed,
      sectionIndex: index,
      sectionCount: count,
      difficulty: difficulty,
    );
  }

  int countMatches(String source, String pattern) {
    return RegExp(pattern).allMatches(source).length;
  }

  setUpAll(() {
    library = loadLibraryFromDisk();
    generator = ProceduralMapGenerator(library: library);
  });

  test('every chunk in the json declares traversal for every level', () {
    final levels = GameDifficulty.values.map((d) => d.storageKey).toSet();
    for (final chunk in library.chunks) {
      expect(chunk.traversable.keys.toSet(), levels, reason: chunk.id);
    }
  });

  test('every chunk in the json declares linear and hazard strips', () {
    final levels = GameDifficulty.values.map((d) => d.storageKey).toSet();
    for (final chunk in library.chunks) {
      expect(chunk.linear.keys.toSet(), levels, reason: chunk.id);
      for (final strip in chunk.hazardStrips) {
        expect(strip.jumpable.keys.toSet(), levels, reason: chunk.id);
        expect(strip.columns, isNotEmpty, reason: chunk.id);
      }
    }
    expect(
      library.chunks.any((chunk) => chunk.hazardStrips.isNotEmpty),
      isTrue,
    );
  });

  test('chunks without linear data default to linear without strips', () {
    final chunk = library.chunks.first;
    final bare = MapChunk(
      id: 'bare',
      biome: chunk.biome,
      kind: chunk.kind,
      width: chunk.width,
      entryHeight: chunk.entryHeight,
      exitHeight: chunk.exitHeight,
      difficulty: chunk.difficulty,
      layers: chunk.layers,
      objects: chunk.objects,
    );
    expect(bare.hazardStrips, isEmpty);
    for (final difficulty in GameDifficulty.values) {
      expect(bare.isLinear(difficulty.storageKey), isTrue);
      expect(bare.layersForLevel(difficulty.storageKey), same(bare.layers));
    }
  });

  test('linear chunks are traversable and every level keeps linear ones', () {
    for (final difficulty in GameDifficulty.values) {
      final key = difficulty.storageKey;
      final usable = library.chunks.where((chunk) => chunk.isLinear(key));
      expect(usable.every((chunk) => chunk.isTraversable(key)), isTrue);
      expect(
        usable.where((chunk) => chunk.kind == ChunkKind.normal).length,
        greaterThanOrEqualTo(5),
        reason: key,
      );
    }
  });

  test('strips that cannot be jumped are paved only on that level', () {
    final chunk = library.chunks.firstWhere(
      (c) => c.hazardStrips.any((strip) => strip.jumpable.containsValue(false)),
    );
    final strip = chunk.hazardStrips.firstWhere(
      (s) => s.jumpable.containsValue(false),
    );
    for (final difficulty in GameDifficulty.values) {
      final key = difficulty.storageKey;
      final ground = chunk.layersForLevel(key)['Ground']!;
      final spikes = chunk.layersForLevel(key)['water/spikes']!;
      final paved = !strip.isJumpable(key);
      strip.safeGround.forEach((column, rows) {
        rows.forEach((row, gid) {
          expect(ground[column][row] == gid, paved, reason: '$key $column');
        });
      });
      strip.clearSpikes.forEach((column, rows) {
        for (final row in rows) {
          expect(spikes[column][row] == 0, paved, reason: '$key $column');
        }
      });
    }
  });

  test('chunks without traversal data default to traversable', () {
    final chunk = library.chunks.first;
    final bare = MapChunk(
      id: 'bare',
      biome: chunk.biome,
      kind: chunk.kind,
      width: chunk.width,
      entryHeight: chunk.entryHeight,
      exitHeight: chunk.exitHeight,
      difficulty: chunk.difficulty,
      layers: chunk.layers,
      objects: chunk.objects,
    );
    for (final difficulty in GameDifficulty.values) {
      expect(bare.isTraversable(difficulty.storageKey), isTrue);
    }
  });

  test('flat chunks without hazards are traversable on every level', () {
    for (final chunk in library.chunksOfKind(ChunkKind.runout)) {
      for (final difficulty in GameDifficulty.values) {
        expect(chunk.isTraversable(difficulty.storageKey), isTrue);
      }
    }
  });

  test('start and end chunks are traversable on every level', () {
    final chunks = [
      ...library.chunksOfKind(ChunkKind.start),
      ...library.chunksOfKind(ChunkKind.end),
    ];
    for (final chunk in chunks) {
      for (final difficulty in GameDifficulty.values) {
        expect(chunk.isTraversable(difficulty.storageKey), isTrue);
      }
    }
  });

  test('every level keeps usable normal chunks to choose from', () {
    for (final difficulty in GameDifficulty.values) {
      final usable = library
          .chunksOfKind(ChunkKind.normal)
          .where((c) => c.difficulty <= difficulty.maxChunkDifficulty)
          .where((c) => c.isUsable(difficulty.storageKey));
      expect(usable.length, greaterThanOrEqualTo(5), reason: '$difficulty');
    }
  });

  test('generated sections only use linear chunks on the level', () {
    for (final difficulty in GameDifficulty.values) {
      for (var seed = 0; seed < 60; seed++) {
        for (var index = 0; index < 3; index++) {
          final chunks = generator.chunksOfSection(
            seed: seed,
            sectionIndex: index,
            sectionCount: 3,
            difficulty: difficulty,
          );
          for (final chunk in chunks) {
            expect(
              chunk.isUsable(difficulty.storageKey),
              isTrue,
              reason: '${chunk.id} $seed $index ${difficulty.storageKey}',
            );
          }
        }
      }
    }
  });

  test('same seed produces same xml', () {
    for (final difficulty in GameDifficulty.values) {
      expect(generate(5, difficulty), generate(5, difficulty));
    }
  });

  test('different seeds produce different xml', () {
    final outputs = seeds
        .map((s) => generate(s, GameDifficulty.medium))
        .toSet();
    expect(outputs.length, seeds.length);
  });

  test('ground reaches the bottom row under shifted chunks', () {
    var filledColumns = 0;
    for (final seed in seeds) {
      for (var index = 1; index < 3; index++) {
        final xml = generate(seed, GameDifficulty.medium, index: index);
        final block = RegExp(
          r'name="Ground"[^>]*>\s*<data encoding="csv">\s*([\s\S]*?)</data>',
        ).firstMatch(xml)!.group(1)!.trim();
        final rows = block
            .split(',\n')
            .map((row) => row.split(',').map(int.parse).toList())
            .toList();
        for (var column = 0; column < rows.first.length; column++) {
          final bottom = rows[rows.length - 1][column];
          final above = rows[rows.length - 2][column];
          if (bottom != 0 && bottom == above) filledColumns++;
        }
      }
    }
    expect(filledColumns, greaterThan(0));
  });

  List<List<int>> readLayer(String xml, String name) {
    final block = RegExp(
      'name="${RegExp.escape(name)}"[^>]*>\\s*<data encoding="csv">\\s*([\\s\\S]*?)</data>',
    ).firstMatch(xml)!.group(1)!.trim();
    return block
        .split(',\n')
        .map((row) => row.split(',').map(int.parse).toList())
        .toList();
  }

  int widestJumpableStrip(String level) {
    var widest = 0;
    for (final chunk in library.chunks.where((c) => c.isLinear(level))) {
      for (final strip in chunk.hazardStrips) {
        if (strip.isJumpable(level) && strip.width > widest) {
          widest = strip.width;
        }
      }
    }
    return widest;
  }

  int longestSpikeRun(List<List<int>> spikes) {
    var longest = 0;
    var current = 0;
    for (var column = 0; column < spikes.first.length; column++) {
      final marked = spikes.any((row) => row[column] != 0);
      current = marked ? current + 1 : 0;
      if (current > longest) longest = current;
    }
    return longest;
  }

  test('jumpable strips are never wider than the simulated reach', () {
    const maxJumpableStripColumns = 5;
    for (final difficulty in GameDifficulty.values) {
      final key = difficulty.storageKey;
      final widest = widestJumpableStrip(key);
      expect(widest, greaterThan(0), reason: key);
      expect(widest, lessThanOrEqualTo(maxJumpableStripColumns), reason: key);
    }
  });

  test('generated sections have no hazard strip beyond the jump reach', () {
    for (final difficulty in GameDifficulty.values) {
      final limit = widestJumpableStrip(difficulty.storageKey);
      for (final seed in [...seeds, 3, 8, 21, 64]) {
        for (var index = 0; index < 3; index++) {
          final xml = generate(seed, difficulty, index: index);
          final run = longestSpikeRun(readLayer(xml, 'water/spikes'));
          expect(
            run,
            lessThanOrEqualTo(limit),
            reason: '$seed $index ${difficulty.storageKey}',
          );
        }
      }
    }
  });

  test('every column has ground or spikes at the bottom', () {
    for (final difficulty in GameDifficulty.values) {
      for (var seed = 0; seed <= 40; seed++) {
        for (var index = 0; index < 3; index++) {
          final xml = generate(seed, difficulty, index: index);
          final ground = readLayer(xml, 'Ground');
          final spikes = readLayer(xml, 'water/spikes');
          for (var column = 0; column < ground.first.length; column++) {
            final hasSupport = List.generate(
              ground.length,
              (row) => ground[row][column] != 0 || spikes[row][column] != 0,
            ).any((filled) => filled);
            expect(hasSupport, isTrue, reason: '$seed $difficulty $index');
          }
        }
      }
    }
  });

  test('width, csv rows and gids are consistent', () {
    final maxGid = library.maxGid;
    for (final difficulty in GameDifficulty.values) {
      for (final seed in seeds) {
        for (var index = 0; index < 3; index++) {
          final xml = generate(seed, difficulty, index: index);
          final width = int.parse(
            RegExp(r'<map [^>]*? width="(\d+)"').firstMatch(xml)!.group(1)!,
          );
          expect(width, greaterThanOrEqualTo(140));
          final blocks = RegExp(
            r'<data encoding="csv">\s*([\s\S]*?)</data>',
          ).allMatches(xml).map((m) => m.group(1)!.trim()).toList();
          expect(blocks, isNotEmpty);
          for (final block in blocks) {
            final rows = block.split(',\n');
            expect(rows.length, 40);
            for (final row in rows) {
              final values = row.split(',').map(int.parse).toList();
              expect(values.length, width);
              for (final value in values) {
                expect(
                  ChunkLibrary.stripFlipBits(value),
                  lessThanOrEqualTo(maxGid),
                );
              }
            }
          }
        }
      }
    }
  });

  test('has exactly one spawn and layer order ends with treehouse_front', () {
    for (var index = 0; index < 3; index++) {
      final xml = generate(3, GameDifficulty.hard, index: index);
      expect(countMatches(xml, 'type="PlayerSpawn"'), 1);
      expect(countMatches(xml, '<objectgroup'), 4);
      final names = RegExp(
        r'<(?:layer|objectgroup) id="\d+" name="([^"]+)"',
      ).allMatches(xml).map((m) => m.group(1)).toList();
      expect(names.last, 'treehouse_front');
    }
  });

  test('last section contains the end chunk, others do not', () {
    final end = library.chunksOfKind(ChunkKind.end).first;
    final endTile = end.layers['Ground']!
        .expand((c) => c)
        .firstWhere((gid) => gid != 0);
    final last = generate(11, GameDifficulty.easy, index: 2);
    expect(readColumns(last, 'Ground').expand((c) => c), contains(endTile));
    expect(last.contains('forest_BG'), isFalse);
    expect(last.contains('mountain_BG'), isTrue);
  });

  test('easy has fewer enemies than hard on average', () {
    int total(GameDifficulty difficulty) {
      return List.generate(30, (seed) {
        final xml = generate(seed, difficulty, index: 1);
        return readEnemies(xml).length;
      }).fold(0, (a, b) => a + b);
    }

    expect(total(GameDifficulty.easy), lessThan(total(GameDifficulty.hard)));
  });

  test('xml is well formed enough', () {
    final xml = generate(8, GameDifficulty.medium);
    expect(xml.startsWith('<?xml'), isTrue);
    expect(xml.trimRight().endsWith('</map>'), isTrue);
    expect(countMatches(xml, '<layer '), countMatches(xml, '</layer>'));
    expect(countMatches(xml, '<group '), countMatches(xml, '</group>'));
    expect(countMatches(xml, '<tileset '), lessThan(library.tilesets.length));
  });

  group('ProceduralMapAssetBundle', () {
    test('serves registered maps and forwards the rest', () async {
      final base = _FakeBundle({'assets/map/a.tsx': 'base'});
      final bundle = ProceduralMapAssetBundle(baseBundle: base);
      const key = 'assets/map/procedural_section_0.tmx';
      bundle.putMap(key, 'first');
      expect(await bundle.loadString(key), 'first');
      bundle.putMap(key, 'second');
      expect(await bundle.loadString(key), 'second');
      final data = await bundle.load(key);
      expect(
        utf8.decode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
        'second',
      );
      expect(await bundle.loadString('assets/map/a.tsx'), 'base');
    });
  });

  group('declared tilesets', () {
    test('every used gid belongs to a declared tileset', () {
      for (final seed in seeds) {
        for (var index = 0; index < 3; index++) {
          final xml = generate(seed, GameDifficulty.medium, index: index);
          final sources = readDeclaredTilesets(
            xml,
          ).map((e) => e.source).toSet();
          for (final gid in readUsedLibraryGids(xml)) {
            final owners = library.tilesets.where(
              (t) => gid >= t.firstGid && gid <= t.lastGid,
            );
            expect(owners, isNotEmpty);
            expect(sources.contains(owners.first.source), isTrue);
          }
        }
      }
    });

    test('items, enemies and animated tilesets are always declared', () {
      final xml = generate(1, GameDifficulty.easy);
      final sources = readDeclaredTilesets(xml).map((e) => e.source).toSet();
      expect(sources, contains('objects/tile_items_v2.tsx'));
      expect(sources, contains('objects/tile_enemies_v2.tsx'));
      final animated = library.tilesets
          .where((t) => t.source.startsWith('anim/'))
          .map((t) => t.source);
      expect(sources.containsAll(animated), isTrue);
    });

    test('section zero omits tilesets of other backgrounds', () {
      const foreign = [
        'tiles/tile_clouds_BG.tsx',
        'objects/tile_plains_mountains_v01.tsx',
      ];
      for (final seed in seeds) {
        final xml = generate(seed, GameDifficulty.medium);
        final used = readUsedLibraryGids(xml);
        final sources = readDeclaredTilesets(xml).map((e) => e.source).toSet();
        for (final source in foreign) {
          final tileset = library.tilesets.firstWhere(
            (t) => t.source == source,
          );
          final isUsed = used.any(
            (g) => g >= tileset.firstGid && g <= tileset.lastGid,
          );
          expect(sources.contains(source), isUsed);
        }
      }
    });

    test('declared tilesets stay ordered by firstgid', () {
      final xml = generate(3, GameDifficulty.hard, index: 2);
      final firstGids = readDeclaredTilesets(
        xml,
      ).map((e) => e.firstGid).toList();
      expect(firstGids, [...firstGids]..sort());
      expect(firstGids.length, lessThan(library.tilesets.length));
    });
  });

  group('slope seams', () {
    const sectionsPerLevel = 12;
    const tileHeight = 64;

    int? surfaceTopOf(int gid, int row) {
      final slope = library.solidity.slopeEdgesOf(gid);
      if (slope != null) return (row + 1) * tileHeight - slope.left;
      if (library.solidity.kindOf(gid) == TileKind.solid) {
        return row * tileHeight;
      }
      return null;
    }

    test('a partial slope end never meets a taller tile', () {
      for (final difficulty in GameDifficulty.values) {
        for (var seed = 0; seed < sectionsPerLevel; seed++) {
          for (var index = 0; index < 3; index++) {
            final xml = generate(seed, difficulty, index: index);
            final ground = readColumns(xml, 'Ground');
            for (var column = 0; column + 1 < ground.length; column++) {
              for (var row = 0; row < ground[column].length; row++) {
                final slope = library.solidity.slopeEdgesOf(
                  ground[column][row],
                );
                if (slope == null) continue;
                if (slope.right <= 0 || slope.right >= tileHeight) continue;
                final exitTop = (row + 1) * tileHeight - slope.right;
                for (final nextRow in [row - 1, row, row + 1]) {
                  if (nextRow < 0) continue;
                  final nextTop = surfaceTopOf(
                    ground[column + 1][nextRow],
                    nextRow,
                  );
                  if (nextTop == null) continue;
                  expect(
                    nextTop,
                    greaterThanOrEqualTo(exitTop),
                    reason:
                        '${difficulty.name} seed $seed section $index '
                        'column $column row $row',
                  );
                }
              }
            }
          }
        }
      }
    });
  });
}

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(files[key]!));
    return ByteData.sublistView(bytes);
  }
}
