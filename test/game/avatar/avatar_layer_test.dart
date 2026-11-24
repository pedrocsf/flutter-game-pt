import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/avatar/avatar.dart';

void main() {
  group('AvatarLayer', () {
    test('is ordered from bottom to top', () {
      expect(
        AvatarLayer.values,
        equals([
          AvatarLayer.body,
          AvatarLayer.pants,
          AvatarLayer.shoes,
          AvatarLayer.shirt,
          AvatarLayer.hair,
        ]),
      );
    });

    test('uses the layer name as file name', () {
      expect(AvatarLayer.body.fileName, equals('body'));
      expect(AvatarLayer.pants.fileName, equals('pants'));
      expect(AvatarLayer.shoes.fileName, equals('shoes'));
      expect(AvatarLayer.shirt.fileName, equals('shirt'));
      expect(AvatarLayer.hair.fileName, equals('hair'));
    });
  });
}
