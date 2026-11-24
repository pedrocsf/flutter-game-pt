import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';

import 'procedural_test_support.dart';

void main() {
  late ProceduralMapGenerator generator;

  const seedCount = 120;
  const sectionCount = 3;
  const frequencyTolerance = 0.12;
  const extraLifeProperty = '<property name="Type" value="ExtraLife"/>';

  setUpAll(() {
    generator = ProceduralMapGenerator(library: loadLibraryFromDisk());
  });

  String xmlOf(int seed, int index, GameDifficulty difficulty) {
    return generator.generateSection(
      seed: seed,
      sectionIndex: index,
      sectionCount: sectionCount,
      difficulty: difficulty,
    );
  }

  int extraLivesIn(String xml) => extraLifeProperty.allMatches(xml).length;

  group('extra life', () {
    test('never appears more than once per section', () {
      for (final difficulty in GameDifficulty.values) {
        for (var seed = 0; seed < seedCount; seed++) {
          for (var index = 0; index < sectionCount; index++) {
            expect(
              extraLivesIn(xmlOf(seed, index, difficulty)),
              lessThanOrEqualTo(1),
              reason: '$difficulty $seed $index',
            );
          }
        }
      }
    });

    test('frequency follows the chance of each level', () {
      for (final difficulty in GameDifficulty.values) {
        var sections = 0;
        var withLife = 0;
        for (var seed = 0; seed < seedCount; seed++) {
          for (var index = 0; index < sectionCount; index++) {
            sections++;
            if (extraLivesIn(xmlOf(seed, index, difficulty)) == 1) withLife++;
          }
        }
        final expected = ExtraLifePlacer.chances[difficulty]!;
        expect(
          withLife / sections,
          closeTo(expected, frequencyTolerance),
          reason: '$difficulty',
        );
      }
    });

    test('chances decrease from easy to hard', () {
      expect(ExtraLifePlacer.chances[GameDifficulty.easy], 0.60);
      expect(ExtraLifePlacer.chances[GameDifficulty.medium], 0.45);
      expect(ExtraLifePlacer.chances[GameDifficulty.hard], 0.30);
    });

    test('same seed gives the same extra life position', () {
      for (final difficulty in GameDifficulty.values) {
        for (var seed = 0; seed < 20; seed++) {
          expect(xmlOf(seed, 1, difficulty), xmlOf(seed, 1, difficulty));
        }
      }
    });

    test('is placed in the second half when one is available', () {
      const placer = ExtraLifePlacer(tileSize: 64);
      ChunkObject energy(double x) => ChunkObject(
        x: x,
        y: 0,
        width: 64,
        height: 64,
        gid: 5,
        type: '',
        properties: const {},
      );
      final items = [energy(64), energy(6000), energy(6400)];
      for (var seed = 0; seed < 30; seed++) {
        final placed = placer.place(
          items: items,
          sectionWidth: 140,
          difficulty: GameDifficulty.easy,
          random: Random(seed),
        );
        final life = placed.indexWhere(
          (item) => item.properties[ExtraLifePlacer.typeProperty] != null,
        );
        if (life == -1) continue;
        expect(life, greaterThan(0));
        expect(placed.length, items.length);
        expect(placed[life].gid, 5);
        expect(placed[life].x, items[life].x);
      }
    });

    test('keeps medals and zone five items untouched', () {
      const placer = ExtraLifePlacer(tileSize: 64);
      const medal = ChunkObject(
        x: 6000,
        y: 0,
        width: 64,
        height: 64,
        gid: 9,
        type: '',
        properties: {'Type': 'Medal'},
      );
      for (var seed = 0; seed < 30; seed++) {
        final placed = placer.place(
          items: const [medal],
          sectionWidth: 140,
          difficulty: GameDifficulty.easy,
          random: Random(seed),
        );
        expect(placed.single.properties['Type'], 'Medal');
      }
    });
  });
}
