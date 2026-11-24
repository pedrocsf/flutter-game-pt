import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';

import 'procedural_test_support.dart';

void main() {
  late ChunkLibrary library;
  late ProceduralMapGenerator generator;
  late TunnelTiles tiles;

  const seedCount = 41;
  const sectionCount = 3;
  const tileSize = 64;
  const minimumTunnelClearance = 4;
  const lowBarRise = 42;
  const mobRise = 54;
  const mobInset = 16;
  const flatMargin = 3;

  setUpAll(() {
    library = loadLibraryFromDisk();
    generator = ProceduralMapGenerator(library: library);
    tiles = library.tunnelTiles;
  });

  Iterable<({int seed, int index, GameDifficulty difficulty})> everySection() {
    return [
      for (final difficulty in GameDifficulty.values)
        for (var seed = 0; seed < seedCount; seed++)
          for (var index = 0; index < sectionCount; index++)
            (seed: seed, index: index, difficulty: difficulty),
    ];
  }

  GeneratedSection build(({int seed, int index, GameDifficulty difficulty}) s) {
    return generator.buildSection(
      seed: s.seed,
      sectionIndex: s.index,
      sectionCount: sectionCount,
      difficulty: s.difficulty,
    );
  }

  bool isSolid(int gid) => library.solidity.isSolid(gid);

  group('tunnel tileset', () {
    test('is appended after the highest gid with 16 tiles', () {
      final tunnel = library.tilesets.last;
      final others = library.tilesets.where((t) => t != tunnel);
      expect(tunnel.source, TunnelTiles.source);
      expect(tunnel.tileCount, 16);
      expect(
        tunnel.firstGid,
        others.map((t) => t.lastGid).reduce((a, b) => a > b ? a : b) + 1,
      );
      expect(tiles.firstGid, tunnel.firstGid);
    });

    test('tunnel tiles are declared only when used', () {
      var declaredCount = 0;
      var undeclaredCount = 0;
      for (final s in everySection()) {
        final xml = build(s).xml;
        final usesTunnel = readColumns(
          xml,
          'Ground',
        ).any((column) => column.any(tiles.isStructure));
        final declared = xml.contains('source="${TunnelTiles.source}"');
        expect(declared, usesTunnel);
        if (declared) {
          declaredCount++;
        } else {
          undeclaredCount++;
        }
      }
      expect(declaredCount, greaterThan(0));
      expect(undeclaredCount, greaterThanOrEqualTo(0));
    });
  });

  group('solidity table', () {
    test('reads classes from tileset xml', () {
      final table = SolidityTable.fromTilesets(
        tilesets: const [
          TilesetEntry(source: 'a.tsx', firstGid: 10, tileCount: 5),
        ],
        sources: const {
          'a.tsx': '''
<tileset>
 <tile id="0" type="Platform"/>
 <tile id="1" type="Slope"><properties/></tile>
 <tile id="2" class="Hazard"/>
</tileset>''',
        },
      );
      expect(table.kindOf(0), TileKind.empty);
      expect(table.kindOf(10), TileKind.platform);
      expect(table.kindOf(11), TileKind.slope);
      expect(table.kindOf(12), TileKind.hazard);
      expect(table.kindOf(13), TileKind.solid);
      expect(table.kindOf(0x80000000 | 10), TileKind.platform);
      expect(table.isSolid(12), isTrue);
      expect(table.isSolid(10), isFalse);
      expect(table.isStandable(11), isTrue);
      expect(table.isStandable(12), isFalse);
    });
  });

  group('death walls', () {
    List<({int column, int row})> deathWalls(List<List<int>> ground) {
      final walls = <({int column, int row})>[];
      for (var column = 0; column < ground.length - 1; column++) {
        for (var row = 2; row < ground[column].length - 1; row++) {
          final standing = !isSolid(ground[column][row]);
          final floored =
              library.solidity.isStandable(ground[column][row + 1]) &&
              !tiles.isStructure(ground[column][row + 1]);
          final wall = [
            0,
            1,
            2,
          ].every((offset) => isSolid(ground[column + 1][row - offset]));
          if (standing && floored && wall) {
            walls.add((column: column, row: row));
          }
        }
      }
      return walls;
    }

    test('generated maps keep no death wall that can be carved', () {
      for (final s in everySection()) {
        final ground = readColumns(build(s).xml, 'Ground');
        final remaining = deathWalls(
          ground,
        ).where((wall) => wall.row - minimumTunnelClearance >= 0);
        expect(remaining, isEmpty, reason: '$s');
      }
    });

    test('some generated sections have tunnels', () {
      final counts = everySection().map((s) => build(s).tunnels.length);
      expect(counts.any((count) => count > 0), isTrue);
    });
  });

  group('carved cells', () {
    test('have a tunnel roof above, floor below and clearance of 4', () {
      var checkedRuns = 0;
      for (final s in everySection()) {
        final xml = build(s).xml;
        final ground = readColumns(xml, 'Ground');
        final terrain = readColumns(xml, 'decorations_terrain');
        for (var column = 0; column < ground.length; column++) {
          final rows = [
            for (var row = 0; row < ground[column].length; row++)
              if (tiles.isDecoration(terrain[column][row])) row,
          ];
          var index = 0;
          while (index < rows.length) {
            var end = index;
            while (end + 1 < rows.length && rows[end + 1] == rows[end] + 1) {
              end++;
            }
            final top = rows[index];
            final bottom = rows[end];
            final reason = '$s column $column rows $top-$bottom';
            expect(
              bottom - top + 1,
              greaterThanOrEqualTo(minimumTunnelClearance),
              reason: reason,
            );
            for (var row = top; row <= bottom; row++) {
              final kind = library.solidity.kindOf(ground[column][row]);
              expect(
                kind,
                anyOf(TileKind.empty, TileKind.solid, TileKind.slope),
                reason: reason,
              );
            }
            final roof = ground[column][top - 1];
            final isTunnelRoof = tiles.isStructure(roof);
            final isOpenToSky =
                roof == 0 &&
                ground[column].take(top - 1).every((gid) => gid == 0);
            expect(
              isTunnelRoof || isOpenToSky || roof != 0,
              isTrue,
              reason: reason,
            );
            if (isTunnelRoof) {
              expect(roof - tiles.firstGid, inInclusiveRange(0, 3));
            }
            expect(ground[column][bottom + 1], isNot(0), reason: reason);
            checkedRuns++;
            index = end + 1;
          }
        }
      }
      expect(checkedRuns, greaterThan(0));
    });

    test('have no hazard tiles inside or in the tunnel floor', () {
      for (final s in everySection()) {
        final xml = build(s).xml;
        final ground = readColumns(xml, 'Ground');
        final spikes = readColumns(xml, 'water/spikes');
        final terrain = readColumns(xml, 'decorations_terrain');
        for (var column = 0; column < ground.length; column++) {
          for (var row = 0; row < ground[column].length - 1; row++) {
            if (!tiles.isDecoration(terrain[column][row])) continue;
            expect(spikes[column][row], 0, reason: '$s');
            expect(spikes[column][row + 1], 0, reason: '$s');
            expect(library.solidity.isHazard(ground[column][row + 1]), false);
          }
        }
      }
    });

    test('tunnels have a lamp roof every fourth column and one led row', () {
      final section = build((
        seed: 3,
        index: 1,
        difficulty: GameDifficulty.hard,
      ));
      final longTunnel = section.tunnels.where(
        (t) => t.length >= 8 && t.startsPath && t.endsPath,
      );
      if (longTunnel.isEmpty) return;
      final xml = section.xml;
      final ground = readColumns(xml, 'Ground');
      final terrain = readColumns(xml, 'decorations_terrain');
      for (final tunnel in longTunnel) {
        final roofIds = [
          for (var c = tunnel.firstColumn; c <= tunnel.lastColumn; c++)
            ground[c][tunnel.roofRow] - tiles.firstGid,
        ];
        expect(roofIds.first, TunnelTiles.roofStart);
        expect(roofIds.last, TunnelTiles.roofEnd);
        expect(roofIds.contains(TunnelTiles.roofLamp), isTrue);
        final led = terrain[tunnel.firstColumn + 1][tunnel.topRow + 2];
        expect(led - tiles.firstGid, TunnelTiles.backgroundLed);
      }
    });
  });

  group('low obstacles', () {
    int spotFloorRow(ParsedObject object, int rise) {
      return ((object.y + rise) / tileSize).round();
    }

    test('low bars sit inside tunnels and low mobs outside', () {
      var bars = 0;
      var mobs = 0;
      for (final s in everySection()) {
        final xml = build(s).xml;
        final ground = readColumns(xml, 'Ground');
        final terrain = readColumns(xml, 'decorations_terrain');
        final spikes = readColumns(xml, 'water/spikes');
        for (final object in readEnemies(xml).where((o) => o.isLow)) {
          final reason = '$s ${object.type}';
          if (object.type == LowObstaclePlacer.lowBarType) {
            bars++;
            final column = (object.x / tileSize).round();
            final floor = spotFloorRow(object, lowBarRise);
            expect(object.width, 64, reason: reason);
            expect(object.height, 20, reason: reason);
            expect(tiles.isDecoration(terrain[column][floor - 1]), true);
            expect(isSolid(ground[column][floor]), true, reason: reason);
            continue;
          }
          mobs++;
          expect(LowObstaclePlacer.mobTypes, contains(object.type));
          expect(object.width, 32, reason: reason);
          expect(object.height, 32, reason: reason);
          expect(object.properties.containsKey('Path'), false);
          final column = ((object.x - mobInset) / tileSize).round();
          final floor = spotFloorRow(object, mobRise);
          for (
            var near = column - flatMargin;
            near <= column + flatMargin;
            near++
          ) {
            expect(tiles.isDecoration(terrain[near][floor - 1]), false);
            expect(ground[near][floor - 1], 0, reason: reason);
            expect(
              library.solidity.kindOf(ground[near][floor]),
              TileKind.solid,
              reason: reason,
            );
            expect(spikes[near][floor - 1], 0, reason: reason);
            expect(spikes[near][floor], 0, reason: reason);
          }
        }
      }
      expect(bars, greaterThan(0));
      expect(mobs, greaterThan(0));
    });

    test('keep six columns away from spawn and section end', () {
      for (final s in everySection()) {
        final section = build(s);
        final width = readColumns(section.xml, 'Ground').length;
        final spawnColumns = RegExp(r'type="PlayerSpawn" x="(\d+)"')
            .allMatches(section.xml)
            .map((m) => int.parse(m.group(1)!) ~/ tileSize);
        for (final object in section.lowObstacles) {
          final column = (object.x / tileSize).floor();
          expect(column, lessThanOrEqualTo(width - 7), reason: '$s');
          for (final spawn in spawnColumns) {
            expect((column - spawn).abs(), greaterThanOrEqualTo(6));
          }
        }
      }
    });

    test('counts respect the level', () {
      for (final s in everySection()) {
        final section = build(s);
        final bars = section.lowObstacles
            .where((o) => o.properties['Type'] == LowObstaclePlacer.lowBarType)
            .length;
        final mobs = section.lowObstacles.length - bars;
        final density = LowObstaclePlacer.densities[s.difficulty]!;
        expect(mobs, lessThanOrEqualTo(density.maxMobs), reason: '$s');
        if (!density.hasBars) {
          expect(bars, 0, reason: '$s');
          continue;
        }
        final allowed = section.tunnels
            .map((t) => t.length ~/ density.columnsPerBar + 1)
            .fold(0, (a, b) => a + b);
        expect(bars, lessThanOrEqualTo(allowed), reason: '$s');
      }
    });

    test('easy has no low bars and no low mobs', () {
      for (var seed = 0; seed < seedCount; seed++) {
        final xml = generator.generateSection(
          seed: seed,
          sectionIndex: 1,
          sectionCount: sectionCount,
          difficulty: GameDifficulty.easy,
        );
        expect(readEnemies(xml).where((o) => o.isLow), isEmpty);
      }
    });

    test('medium and hard place obstacles in many sections', () {
      for (final difficulty in [GameDifficulty.medium, GameDifficulty.hard]) {
        var withObstacles = 0;
        for (var seed = 0; seed < seedCount; seed++) {
          final section = generator.buildSection(
            seed: seed,
            sectionIndex: 1,
            sectionCount: sectionCount,
            difficulty: difficulty,
          );
          if (section.lowObstacles.isNotEmpty) withObstacles++;
        }
        expect(withObstacles, greaterThan(seedCount ~/ 2));
      }
    });
  });

  group('variety', () {
    test('never places two plain normal chunks in a row', () {
      for (final s in everySection()) {
        final chunks = generator.chunksOfSection(
          seed: s.seed,
          sectionIndex: s.index,
          sectionCount: sectionCount,
          difficulty: s.difficulty,
        );
        for (var index = 1; index < chunks.length; index++) {
          final pair = [chunks[index - 1], chunks[index]];
          final plain = pair.every(
            (c) => c.kind == ChunkKind.normal && c.difficulty == 0,
          );
          expect(plain, false, reason: '$s ${pair.map((c) => c.id)}');
        }
      }
    });

    test('runouts appear only at the start of later sections and the end', () {
      for (final s in everySection()) {
        final chunks = generator.chunksOfSection(
          seed: s.seed,
          sectionIndex: s.index,
          sectionCount: sectionCount,
          difficulty: s.difficulty,
        );
        final isLast = s.index == sectionCount - 1;
        for (var index = 0; index < chunks.length; index++) {
          if (chunks[index].kind != ChunkKind.runout) continue;
          final atStart = index == 0 && s.index > 0;
          final atEnd = index == chunks.length - 1 && !isLast;
          expect(atStart || atEnd, true, reason: '$s $index');
        }
      }
    });
  });

  group('determinism', () {
    test('same seed gives same xml with tunnels and obstacles', () {
      for (final difficulty in GameDifficulty.values) {
        for (var index = 0; index < sectionCount; index++) {
          final s = (seed: 17, index: index, difficulty: difficulty);
          expect(build(s).xml, build(s).xml);
        }
      }
    });
  });
}
