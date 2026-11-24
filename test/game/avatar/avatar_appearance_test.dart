import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/avatar/avatar.dart';

void main() {
  group('AvatarAppearance', () {
    const tint = Color(0xFF2050C0);

    test('standard uses the default variant without tint in every layer', () {
      const appearance = AvatarAppearance.standard();

      for (final layer in AvatarLayer.values) {
        expect(appearance.styleOf(layer), equals(const AvatarLayerStyle()));
      }
    });

    test('falls back to the default style for a layer not listed', () {
      const appearance = AvatarAppearance(layers: {});

      expect(
        appearance.styleOf(AvatarLayer.hair),
        equals(const AvatarLayerStyle()),
      );
    });

    test('builds the asset path from layer, variant and animation', () {
      const appearance = AvatarAppearance.standard();

      expect(
        appearance.assetPath(AvatarLayer.shirt, AvatarAnimation.run),
        equals('anim/avatar/shirt_default_run.png'),
      );
      expect(
        appearance.assetPath(AvatarLayer.body, AvatarAnimation.deathFaint),
        equals('anim/avatar/body_default_deathFaint.png'),
      );
    });

    test('uses the variant of the layer in the asset path', () {
      final appearance = const AvatarAppearance.standard().withLayer(
        AvatarLayer.pants,
        const AvatarLayerStyle(variant: 'slim'),
      );

      expect(
        appearance.assetPath(AvatarLayer.pants, AvatarAnimation.idle),
        equals('anim/avatar/pants_slim_idle.png'),
      );
      expect(
        appearance.assetPath(AvatarLayer.shirt, AvatarAnimation.idle),
        equals('anim/avatar/shirt_default_idle.png'),
      );
    });

    test('withLayer does not change the original appearance', () {
      const original = AvatarAppearance.standard();

      final replaced = original.withLayer(
        AvatarLayer.hair,
        const AvatarLayerStyle(tint: tint),
      );

      expect(replaced, isNot(equals(original)));
      expect(
        original.styleOf(AvatarLayer.hair),
        equals(const AvatarLayerStyle()),
      );
    });

    test('withLayer replaces only the given layer', () {
      const style = AvatarLayerStyle(tint: tint);

      final appearance = const AvatarAppearance.standard().withLayer(
        AvatarLayer.hair,
        style,
      );

      expect(appearance.styleOf(AvatarLayer.hair), equals(style));
      expect(
        appearance.styleOf(AvatarLayer.shirt),
        equals(const AvatarLayerStyle()),
      );
    });

    test('copyWith keeps the layers when none are given', () {
      const appearance = AvatarAppearance.standard();

      expect(appearance.copyWith(), equals(appearance));
    });

    test('copyWith replaces the layers when given', () {
      const appearance = AvatarAppearance.standard();
      const replacement = AvatarAppearance(
        layers: {AvatarLayer.body: AvatarLayerStyle(variant: 'dark')},
      );

      expect(
        appearance.copyWith(layers: replacement.layers),
        equals(replacement),
      );
    });

    test('equal when the same layers are set', () {
      expect(
        const AvatarAppearance.standard(),
        equals(const AvatarAppearance.standard()),
      );
      expect(
        const AvatarAppearance.standard().withLayer(
          AvatarLayer.shirt,
          const AvatarLayerStyle(tint: tint),
        ),
        equals(
          const AvatarAppearance.standard().withLayer(
            AvatarLayer.shirt,
            const AvatarLayerStyle(tint: tint),
          ),
        ),
      );
    });

    test('different when a layer has another variant or tint', () {
      const standard = AvatarAppearance.standard();

      expect(
        standard.withLayer(
          AvatarLayer.shirt,
          const AvatarLayerStyle(variant: 'blue'),
        ),
        isNot(equals(standard)),
      );
      expect(
        standard.withLayer(
          AvatarLayer.shirt,
          const AvatarLayerStyle(tint: tint),
        ),
        isNot(equals(standard)),
      );
    });
  });
}
