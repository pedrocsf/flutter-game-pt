import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';

import 'procedural_test_support.dart';

void main() {
  late ChunkLibrary library;
  late ProceduralMapGenerator generator;
  late BaseFloorExtender extender;

  const seedCount = 41;
  const sectionCount = 3;
  const lastSectionIndex = sectionCount - 1;
  const reportedSeeds = [1, 3];
  const reportedFirstColumn = 98;
  const lowFloorMinimumRow = 30;
  const dropTolerance = BaseFloorExtender.dropTolerance;

  setUpAll(() {
    library = loadLibraryFromDisk();
    generator = ProceduralMapGenerator(library: library);
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

  bool crossesPreservedHole(GeneratedSection section, int column) {
    return section.preservedHazardSpans.any(
      (span) => span.containsColumn(column),
    );
  }

  List<int?> profileOf(GeneratedSection section) {
    return extender.baseProfile(
      readColumns(section.xml, 'Ground'),
      preservedSpans: section.preservedHazardSpans,
    );
  }

  bool hasHazard(List<List<int>> ground, List<List<int>> spikes, int column) {
    return ground[column].any(library.solidity.isHazard) ||
        spikes[column].any((tile) => tile != 0);
  }

  test('every column of every generated section has a base floor', () {
    for (final s in everySection()) {
      final profile = profileOf(build(s));
      final missing = [
        for (var column = 0; column < profile.length; column++)
          if (profile[column] == null) column,
      ];
      expect(missing, isEmpty, reason: '$s');
    }
  });

  test('base floor never rises more than two rows except in tunnels', () {
    for (final s in everySection()) {
      final section = build(s);
      final profile = profileOf(section);
      for (var column = 1; column < profile.length; column++) {
        final rise = profile[column - 1]! - profile[column]!;
        if (rise <= dropTolerance) continue;
        final inTunnel = section.tunnels.any((t) => t.containsColumn(column));
        expect(inTunnel, isTrue, reason: '$s column $column rise $rise');
      }
    }
  });

  test('reported seeds keep a low floor until the end of the last section', () {
    for (final seed in reportedSeeds) {
      final section = build((
        seed: seed,
        index: lastSectionIndex,
        difficulty: GameDifficulty.easy,
      ));
      final profile = profileOf(section);
      for (
        var column = reportedFirstColumn;
        column < profile.length;
        column++
      ) {
        expect(profile[column], isNotNull, reason: 'seed $seed $column');
        expect(
          profile[column],
          greaterThanOrEqualTo(lowFloorMinimumRow),
          reason: 'seed $seed column $column',
        );
      }
    }
  });

  test('base floor tile is standable in sections with extended columns', () {
    for (final s in everySection()) {
      final section = build(s);
      if (section.extendedColumns == 0) continue;
      final ground = readColumns(section.xml, 'Ground');
      final profile = profileOf(section);
      for (var column = 0; column < ground.length; column++) {
        if (crossesPreservedHole(section, column)) continue;
        final base = profile[column]!;
        expect(
          library.solidity.isStandable(ground[column][base]),
          isTrue,
          reason: '$s column $column',
        );
      }
    }
  });

  test('jumpable hazard strips from placed chunks survive extension', () {
    for (final s in everySection()) {
      final section = build(s);
      final ground = readColumns(section.xml, 'Ground');
      final spikes = readColumns(section.xml, 'water/spikes');
      for (final span in section.jumpableHazardSpans) {
        for (
          var column = span.firstColumn;
          column <= span.lastColumn;
          column++
        ) {
          if (section.tunnels.any((t) => t.containsColumn(column))) continue;
          expect(
            hasHazard(ground, spikes, column),
            isTrue,
            reason: '$s span ${span.firstColumn}-${span.lastColumn} $column',
          );
        }
      }
    }
  });

  test('some sections preserve jumpable hazard strips', () {
    final kept = everySection().where(
      (s) => build(s).preservedHazardSpans.isNotEmpty,
    );
    expect(kept, isNotEmpty);
  });

  test('some sections need extension', () {
    final extended = everySection().where((s) => build(s).extendedColumns > 0);
    expect(extended, isNotEmpty);
  });
}
