import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';

import 'procedural_test_support.dart';

typedef _SectionKey = ({int seed, int index, GameDifficulty difficulty});

void main() {
  late ChunkLibrary library;
  late ProceduralMapGenerator generator;

  const seedCount = 41;
  const sectionCount = 3;
  const corridorHeight = Tunnel.clearHeight;
  const minimumKeptHazardRatio = 0.9;

  setUpAll(() {
    library = loadLibraryFromDisk();
    generator = ProceduralMapGenerator(library: library);
  });

  Iterable<_SectionKey> everySection() {
    return [
      for (final difficulty in GameDifficulty.values)
        for (var seed = 0; seed < seedCount; seed++)
          for (var index = 0; index < sectionCount; index++)
            (seed: seed, index: index, difficulty: difficulty),
    ];
  }

  GeneratedSection build(_SectionKey key) {
    return generator.buildSection(
      seed: key.seed,
      sectionIndex: key.index,
      sectionCount: sectionCount,
      difficulty: key.difficulty,
    );
  }

  group('bottom route', () {
    test('covers every column of the section', () {
      for (final key in everySection()) {
        final section = build(key);
        final ground = readColumns(section.xml, 'Ground');
        expect(section.route.length, ground.length, reason: '$key');
      }
    });

    test('has a standable floor under every column outside jump gaps', () {
      for (final key in everySection()) {
        final section = build(key);
        final ground = readColumns(section.xml, 'Ground');
        for (var column = 0; column < ground.length; column++) {
          if (section.route.isGap(column)) continue;
          final floor = ground[column][section.route.surfaceRowAt(column)];
          expect(
            library.solidity.isStandable(floor),
            isTrue,
            reason: '$key column $column',
          );
        }
      }
    });

    test('keeps four rows of free ground above every column', () {
      for (final key in everySection()) {
        final section = build(key);
        final ground = readColumns(section.xml, 'Ground');
        final spikes = readColumns(section.xml, 'water/spikes');
        for (var column = 0; column < ground.length; column++) {
          final standRow = section.route.standRowAt(column);
          for (var offset = 0; offset < corridorHeight; offset++) {
            final row = standRow - offset;
            if (row < 0) continue;
            expect(
              ground[column][row],
              0,
              reason: '$key column $column row $row',
            );
            if (section.route.isGap(column)) continue;
            expect(
              spikes[column][row],
              0,
              reason: '$key column $column row $row',
            );
          }
        }
      }
    });

    test('never climbs more than the maximum step', () {
      for (final key in everySection()) {
        final section = build(key);
        final route = section.route;
        for (var column = 1; column < route.length; column++) {
          final rise = route.rows[column - 1] - route.rows[column];
          expect(
            rise,
            lessThanOrEqualTo(RoutePlanner.maxStepUp),
            reason: '$key column $column',
          );
        }
      }
    });

    test('falls only onto ground and never onto a hazard', () {
      for (final key in everySection()) {
        final section = build(key);
        final ground = readColumns(section.xml, 'Ground');
        for (var column = 1; column < ground.length; column++) {
          if (section.route.isGap(column)) continue;
          final floor = ground[column][section.route.surfaceRowAt(column)];
          expect(library.solidity.isHazard(floor), isFalse, reason: '$key');
        }
      }
    });

    test('only crosses jump gaps that the level can jump', () {
      for (final key in everySection()) {
        final section = build(key);
        for (final gap in section.route.gaps) {
          final isJumpable = section.jumpableHazardSpans.any(
            (span) =>
                span.firstColumn == gap.firstColumn &&
                span.lastColumn == gap.lastColumn,
          );
          expect(isJumpable, isTrue, reason: '$key gap ${gap.firstColumn}');
        }
      }
    });

    test('jump gaps keep their hazard and have a reachable exit floor', () {
      var checkedGaps = 0;
      for (final key in everySection()) {
        final section = build(key);
        final route = section.route;
        final ground = readColumns(section.xml, 'Ground');
        final spikes = readColumns(section.xml, 'water/spikes');
        for (final gap in route.gaps) {
          final hasHazard = [
            for (
              var column = gap.firstColumn;
              column <= gap.lastColumn;
              column++
            )
              ground[column].any(library.solidity.isHazard) ||
                  spikes[column].any((tile) => tile != 0),
          ];
          expect(hasHazard.any((value) => value), isTrue, reason: '$key');
          final exit = gap.lastColumn + 1;
          if (exit < ground.length) {
            final rise = route.rows[gap.firstColumn] - route.rows[exit];
            expect(
              rise,
              inInclusiveRange(
                -RoutePlanner.maxGapDrop,
                RoutePlanner.maxStepUp,
              ),
            );
          }
          checkedGaps++;
        }
      }
      expect(checkedGaps, greaterThan(0));
    });

    test('most jumpable hazard columns survive the route clearance', () {
      var total = 0;
      var kept = 0;
      for (final key in everySection()) {
        final section = build(key);
        final ground = readColumns(section.xml, 'Ground');
        final spikes = readColumns(section.xml, 'water/spikes');
        for (final span in section.jumpableHazardSpans) {
          for (
            var column = span.firstColumn;
            column <= span.lastColumn;
            column++
          ) {
            total++;
            final hasHazard =
                ground[column].any(library.solidity.isHazard) ||
                spikes[column].any((tile) => tile != 0);
            if (hasHazard) kept++;
          }
        }
      }
      expect(total, greaterThan(0));
      expect(kept / total, greaterThanOrEqualTo(minimumKeptHazardRatio));
    });

    test('same seed gives the same route', () {
      for (final difficulty in GameDifficulty.values) {
        final key = (seed: 17, index: 1, difficulty: difficulty);
        expect(build(key).route.rows, build(key).route.rows);
      }
    });
  });

  group('route planner', () {
    const solidGid = 1;
    const hazardGid = 2;
    const mapHeight = 20;
    const floorRow = 12;
    const planner = RoutePlanner(
      solidity: SolidityTable({hazardGid: 'Hazard'}),
    );

    SectionGrid gridOf(int width, Map<(int, int), int> cells) {
      final layers = {
        for (final name in [
          SectionGrid.groundLayer,
          SectionGrid.spikesLayer,
          SectionGrid.terrainDecorationLayer,
        ])
          name: List.generate(width, (_) => List.filled(mapHeight, 0)),
      };
      final grid = SectionGrid(width: width, height: mapHeight, layers: layers);
      cells.forEach((position, gid) {
        grid.setTile(SectionGrid.groundLayer, position.$1, position.$2, gid);
      });
      return grid;
    }

    Map<(int, int), int> floorWith({
      int width = 12,
      Set<int> holes = const {},
      Map<(int, int), int> extra = const {},
    }) {
      return {
        for (var column = 0; column < width; column++)
          if (!holes.contains(column))
            for (var row = floorRow; row < mapHeight; row++)
              (column, row): solidGid,
        ...extra,
      };
    }

    test('keeps a flat floor', () {
      final route = planner.plan(gridOf(12, floorWith()));
      expect(route.rows.every((row) => row == floorRow), isTrue);
      expect(route.fillColumns, isEmpty);
    });

    test('fills a pit that has no ground below', () {
      final route = planner.plan(gridOf(12, floorWith(holes: {5, 6, 7})));
      expect(route.fillColumns, {5, 6, 7});
      expect(route.rows.every((row) => row == floorRow), isTrue);
    });

    test('follows a drop onto the ground below', () {
      final cells = {
        for (var column = 0; column < 6; column++)
          for (var row = floorRow; row < mapHeight; row++)
            (column, row): solidGid,
        for (var column = 6; column < 12; column++)
          for (var row = floorRow + 3; row < mapHeight; row++)
            (column, row): solidGid,
      };
      final route = planner.plan(gridOf(12, cells));
      expect(route.rows[5], floorRow);
      expect(route.rows[6], floorRow + 3);
      expect(route.fillColumns, isEmpty);
    });

    test('climbs one row but keeps its level at a taller wall', () {
      final step = planner.plan(
        gridOf(12, floorWith(extra: {(6, floorRow - 1): solidGid})),
      );
      expect(step.rows[6], floorRow - 1);
      final wall = planner.plan(
        gridOf(
          12,
          floorWith(
            extra: {
              for (var row = floorRow - 4; row < floorRow; row++)
                (6, row): solidGid,
            },
          ),
        ),
      );
      expect(wall.rows[6], floorRow);
      expect(wall.fillColumns, isEmpty);
    });

    test('replaces a hazard on the floor level', () {
      final route = planner.plan(
        gridOf(12, floorWith(extra: {(6, floorRow): hazardGid})),
      );
      expect(route.fillColumns, {6});
    });

    test('keeps a jumpable hazard span as a gap', () {
      final cells = floorWith(
        extra: {(5, floorRow): hazardGid, (6, floorRow): hazardGid},
      );
      final route = planner.plan(
        gridOf(12, cells),
        jumpableSpans: const [HazardSpan(firstColumn: 5, lastColumn: 6)],
      );
      expect(route.isGap(5), isTrue);
      expect(route.isGap(6), isTrue);
      expect(route.isGap(7), isFalse);
      expect(route.fillColumns, isEmpty);
    });

    test('clearance removes ground and spikes above the route', () {
      final grid = gridOf(
        12,
        floorWith(
          extra: {(6, floorRow - 4): solidGid, (6, floorRow - 5): solidGid},
        ),
      );
      final route = planner.plan(grid);
      grid.setTile(SectionGrid.spikesLayer, 6, floorRow - 2, 7);
      RouteClearance(solidity: planner.solidity).clear(grid, route);
      final standRow = route.standRowAt(6);
      for (var offset = 0; offset < corridorHeight; offset++) {
        expect(grid.tileAt(SectionGrid.groundLayer, 6, standRow - offset), 0);
        expect(grid.tileAt(SectionGrid.spikesLayer, 6, standRow - offset), 0);
      }
      expect(
        grid.tileAt(SectionGrid.groundLayer, 6, standRow - corridorHeight),
        solidGid,
      );
    });
  });
}
