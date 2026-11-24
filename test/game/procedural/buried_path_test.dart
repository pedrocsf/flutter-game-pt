import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';

import 'procedural_test_support.dart';

void main() {
  late ChunkLibrary library;
  late ProceduralMapGenerator generator;
  late TunnelTiles tiles;
  late BaseFloorExtender extender;

  const seedCount = 41;
  const sectionCount = 3;
  const corridorHeight = Tunnel.clearHeight;
  const surfaceTerrainTilesAllowed = 1;

  setUpAll(() {
    library = loadLibraryFromDisk();
    generator = ProceduralMapGenerator(library: library);
    tiles = library.tunnelTiles;
    extender = BaseFloorExtender(solidity: library.solidity);
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

  int plainTerrainTilesInCorridor(
    List<List<int>> terrain,
    int column,
    int standRow,
  ) {
    var count = 0;
    for (var row = standRow - corridorHeight + 1; row <= standRow; row++) {
      if (row < 0) continue;
      final gid = terrain[column][row];
      if (gid != 0 && !tiles.isDecoration(gid)) count++;
    }
    return count;
  }

  List<int> standRowsOf(GeneratedSection section, List<List<int>> ground) {
    final rows = <int>[];
    for (var column = 0; column < ground.length; column++) {
      final inSpan = section.preservedHazardSpans.any(
        (span) => span.containsColumn(column),
      );
      final base = inSpan ? null : extender.baseRowOf(ground[column]);
      rows.add(base == null ? -1 : base - 1);
    }
    return rows;
  }

  group('buried paths', () {
    test('no base floor cell keeps terrain drawn over the player', () {
      for (final s in everySection()) {
        final section = build(s);
        final ground = readColumns(section.xml, 'Ground');
        final terrain = readColumns(section.xml, 'decorations_terrain');
        final standRows = standRowsOf(section, ground);
        for (var column = 0; column < ground.length; column++) {
          final rows = {
            if (standRows[column] >= 0) standRows[column],
            for (final tunnel in section.tunnels)
              if (tunnel.containsColumn(column)) tunnel.standRow,
          };
          for (final row in rows) {
            expect(
              plainTerrainTilesInCorridor(terrain, column, row),
              lessThanOrEqualTo(surfaceTerrainTilesAllowed),
              reason: '$s column $column stand row $row',
            );
          }
        }
      }
    });

    test('are carved in many sections with the same tunnel design', () {
      var withBuried = 0;
      for (final s in everySection()) {
        final buried = build(
          s,
        ).tunnels.where((tunnel) => tunnel.kind == TunnelKind.buriedPath);
        if (buried.isNotEmpty) withBuried++;
      }
      expect(withBuried, greaterThan(everySection().length ~/ 2));
    });

    test('every buried path has an entry and an exit arch', () {
      for (final s in everySection()) {
        final section = build(s);
        final terrain = readColumns(section.xml, 'decorations_terrain');
        for (final tunnel in section.tunnels.where(
          (t) => t.kind == TunnelKind.buriedPath,
        )) {
          if (tunnel.startsPath) {
            final id =
                terrain[tunnel.firstColumn][tunnel.standRow] - tiles.firstGid;
            expect(id, TunnelTiles.entryArch, reason: '$s');
          }
          if (tunnel.endsPath) {
            final id =
                terrain[tunnel.lastColumn][tunnel.standRow] - tiles.firstGid;
            expect(
              id,
              anyOf(TunnelTiles.exitArch, TunnelTiles.entryArch),
              reason: '$s',
            );
          }
        }
      }
    });

    test('roofs never plug a column that is open to the sky', () {
      for (final s in everySection()) {
        final section = build(s);
        final ground = readColumns(section.xml, 'Ground');
        for (final tunnel in section.tunnels) {
          if (tunnel.kind != TunnelKind.buriedPath) continue;
          for (
            var column = tunnel.firstColumn;
            column <= tunnel.lastColumn;
            column++
          ) {
            if (!tiles.isStructure(ground[column][tunnel.roofRow])) continue;
            final hasGroundAbove = ground[column]
                .take(tunnel.roofRow)
                .any((gid) => gid != 0);
            expect(hasGroundAbove, isTrue, reason: '$s column $column');
          }
        }
      }
    });

    test('same seed gives the same tunnels', () {
      for (final difficulty in GameDifficulty.values) {
        final s = (seed: 23, index: 1, difficulty: difficulty);
        final first = build(s).tunnels;
        final second = build(s).tunnels;
        expect(first.length, second.length);
        for (var index = 0; index < first.length; index++) {
          expect(first[index].firstColumn, second[index].firstColumn);
          expect(first[index].lastColumn, second[index].lastColumn);
          expect(first[index].standRow, second[index].standRow);
        }
      }
    });
  });
}
