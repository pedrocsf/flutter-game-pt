import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/entities/item_type.dart';

void main() {
  group('ItemType', () {
    group('fromType', () {
      test('returns medal for "Medal"', () {
        expect(ItemType.fromType('Medal'), ItemType.medal);
      });

      test('returns zoneFive for "ZoneFive"', () {
        expect(ItemType.fromType('ZoneFive'), ItemType.zoneFive);
      });

      test('returns extraLife for "ExtraLife"', () {
        expect(ItemType.fromType('ExtraLife'), ItemType.extraLife);
      });

      test('returns energy for null', () {
        expect(ItemType.fromType(null), ItemType.energy);
      });

      test('returns energy for an unknown type', () {
        expect(ItemType.fromType('Unknown'), ItemType.energy);
      });

      test('returns energy for an empty type', () {
        expect(ItemType.fromType(''), ItemType.energy);
      });
    });

    group('points', () {
      test('energy is worth ItemType.energyPoints (10)', () {
        expect(ItemType.energy.points, ItemType.energyPoints);
        expect(ItemType.energy.points, 10);
      });

      test('medal is worth ItemType.medalPoints (1000)', () {
        expect(ItemType.medal.points, ItemType.medalPoints);
        expect(ItemType.medal.points, 1000);
      });

      test('zoneFive is worth ItemType.zoneFivePoints (0)', () {
        expect(ItemType.zoneFive.points, ItemType.zoneFivePoints);
        expect(ItemType.zoneFive.points, 0);
      });

      test('extraLife is worth ItemType.extraLifePoints (0)', () {
        expect(ItemType.extraLife.points, ItemType.extraLifePoints);
        expect(ItemType.extraLife.points, 0);
      });

      test('extraLife at full lives is worth 500 points', () {
        expect(ItemType.extraLifeFullLivesPoints, 500);
      });
    });

    group('isSpecial', () {
      test('is true for medal, zoneFive and extraLife', () {
        expect(ItemType.medal.isSpecial, isTrue);
        expect(ItemType.zoneFive.isSpecial, isTrue);
        expect(ItemType.extraLife.isSpecial, isTrue);
      });

      test('is false for energy', () {
        expect(ItemType.energy.isSpecial, isFalse);
      });
    });
  });
}
