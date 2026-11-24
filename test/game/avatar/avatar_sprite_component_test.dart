import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/game/avatar/avatar.dart';

class _MockImage extends Mock implements Image {}

class _MockImages extends Mock implements Images {}

Images _fakeImages() {
  final image = _MockImage();
  when(() => image.width).thenReturn(4096);
  when(() => image.height).thenReturn(128);

  final images = _MockImages();
  when(() => images.load(any())).thenAnswer((_) async => image);
  return images;
}

Future<AvatarSpriteComponent> _loadAvatar(
  FlameGame game, {
  AvatarAppearance appearance = const AvatarAppearance.standard(),
  AvatarAnimation animation = AvatarAnimation.run,
}) {
  game.images = _fakeImages();
  return AvatarSpriteComponent.load(
    game: game,
    animation: animation,
    appearance: appearance,
    size: Vector2.all(64),
  );
}

List<AvatarLayerComponent> _layersOf(AvatarSpriteComponent avatar) {
  return avatar.children.whereType<AvatarLayerComponent>().toList();
}

void main() {
  group('AvatarSpriteComponent', () {
    testWithGame<FlameGame>(
      'creates one layer per AvatarLayer',
      FlameGame.new,
      (game) async {
        final avatar = await _loadAvatar(game);
        await game.ensureAdd(avatar);

        expect(_layersOf(avatar), hasLength(AvatarLayer.values.length));
      },
    );

    testWithGame<FlameGame>(
      'keeps every layer in the same frame',
      FlameGame.new,
      (game) async {
        final avatar = await _loadAvatar(game);
        await game.ensureAdd(avatar);

        game.update(.1);

        final frames = _layersOf(
          avatar,
        ).map((layer) => layer.frameIndex).toSet();
        expect(frames, hasLength(1));
        expect(frames.single, greaterThan(0));
      },
    );

    testWithGame<FlameGame>('reset restarts every layer', FlameGame.new, (
      game,
    ) async {
      final avatar = await _loadAvatar(game);
      await game.ensureAdd(avatar);
      game.update(.2);

      avatar.reset();

      for (final layer in _layersOf(avatar)) {
        expect(layer.frameIndex, equals(0));
      }
    });

    testWithGame<FlameGame>('passes opacity to every layer', FlameGame.new, (
      game,
    ) async {
      final avatar = await _loadAvatar(game);
      await game.ensureAdd(avatar);

      avatar.opacity = .5;

      for (final layer in _layersOf(avatar)) {
        expect(layer.opacity, closeTo(.5, .01));
      }
    });

    testWithGame<FlameGame>(
      'lets OpacityEffect fade the avatar out',
      FlameGame.new,
      (game) async {
        final avatar = await _loadAvatar(game);
        await game.ensureAdd(avatar);
        avatar.add(OpacityEffect.fadeOut(EffectController(duration: 1)));

        game.update(.5);

        expect(avatar.opacity, closeTo(.5, .05));
        for (final layer in _layersOf(avatar)) {
          expect(layer.opacity, closeTo(.5, .05));
        }
      },
    );

    testWithGame<FlameGame>(
      'setColor applies the color to every layer',
      FlameGame.new,
      (game) async {
        final avatar = await _loadAvatar(game);
        await game.ensureAdd(avatar);

        avatar.setColor(const Color(0xFF00FF00));

        for (final layer in _layersOf(avatar)) {
          expect(layer.paint.color, equals(const Color(0xFF00FF00)));
        }
      },
    );

    testWithGame<FlameGame>(
      'applies the tint of a layer as a color filter',
      FlameGame.new,
      (game) async {
        final appearance = const AvatarAppearance.standard().withLayer(
          AvatarLayer.shirt,
          const AvatarLayerStyle(tint: Color(0xFF2050C0)),
        );
        final avatar = await _loadAvatar(game, appearance: appearance);
        await game.ensureAdd(avatar);

        final layers = _layersOf(avatar);
        final shirtIndex = AvatarLayer.values.indexOf(AvatarLayer.shirt);

        expect(layers[shirtIndex].paint.colorFilter, isNotNull);
        for (var index = 0; index < layers.length; index++) {
          if (index == shirtIndex) continue;
          expect(layers[index].paint.colorFilter, isNull);
        }
      },
    );
    testWithGame<FlameGame>(
      'shares a single frame index between the avatar and its layers',
      FlameGame.new,
      (game) async {
        final avatar = await _loadAvatar(game);
        await game.ensureAdd(avatar);

        for (var step = 0; step < 40; step++) {
          game.update(avatarStepTime * .7);
          for (final layer in _layersOf(avatar)) {
            expect(layer.frameIndex, equals(avatar.frameIndex));
            expect(
              layer.currentSprite,
              same(layer.animation.frames[avatar.frameIndex].sprite),
            );
          }
        }
      },
    );

    testWithGame<FlameGame>(
      'keeps layers in sync when removed, reset and added again',
      FlameGame.new,
      (game) async {
        final avatar = await _loadAvatar(game);
        await game.ensureAdd(avatar);
        game.update(avatarStepTime * 5);

        avatar.removeFromParent();
        game.processLifecycleEvents();
        avatar.reset();
        game.update(avatarStepTime * 3);
        await game.ensureAdd(avatar);
        game.update(avatarStepTime * 2.5);

        expect(avatar.frameIndex, equals(2));
        for (final layer in _layersOf(avatar)) {
          expect(layer.frameIndex, equals(2));
        }
      },
    );

    testWithGame<FlameGame>(
      'stops on the last frame of an animation that does not loop',
      FlameGame.new,
      (game) async {
        final avatar = await _loadAvatar(
          game,
          animation: AvatarAnimation.deathFaint,
        );
        await game.ensureAdd(avatar);

        game.update(avatarStepTime * AvatarAnimation.deathFaint.frameCount * 2);

        final lastFrame = AvatarAnimation.deathFaint.frameCount - 1;
        expect(avatar.frameIndex, equals(lastFrame));
        for (final layer in _layersOf(avatar)) {
          expect(layer.frameIndex, equals(lastFrame));
        }
      },
    );

    testWithGame<FlameGame>(
      'smooths the downscale of every layer',
      FlameGame.new,
      (game) async {
        final avatar = await _loadAvatar(game);
        await game.ensureAdd(avatar);

        for (final layer in _layersOf(avatar)) {
          expect(
            layer.paint.filterQuality,
            equals(AvatarSpriteComponent.layerFilterQuality),
          );
          expect(layer.paint.filterQuality, isNot(FilterQuality.none));
        }
      },
    );

    testWithGame<FlameGame>(
      'keeps the tint and the smoothing when the opacity changes',
      FlameGame.new,
      (game) async {
        final appearance = const AvatarAppearance.standard().withLayer(
          AvatarLayer.shirt,
          const AvatarLayerStyle(tint: Color(0xFF2050C0)),
        );
        final avatar = await _loadAvatar(game, appearance: appearance);
        await game.ensureAdd(avatar);
        final shirt = _layersOf(
          avatar,
        )[AvatarLayer.values.indexOf(AvatarLayer.shirt)];

        avatar.opacity = .25;

        expect(
          shirt.paint.colorFilter,
          equals(const ColorFilter.mode(Color(0xFF2050C0), BlendMode.modulate)),
        );
        expect(
          shirt.paint.filterQuality,
          equals(AvatarSpriteComponent.layerFilterQuality),
        );
        expect(shirt.paint.color.a, closeTo(.25, .01));
      },
    );

    testWithGame<FlameGame>(
      'setColor also hides and shows the zone five glow',
      FlameGame.new,
      (game) async {
        final avatar = await _loadAvatar(game);
        final glow = ZoneFiveGlowComponent(avatarSize: avatar.size);
        avatar.add(glow);
        await game.ensureAdd(avatar);

        avatar.setColor(const Color(0x00000000));

        expect(avatar.opacity, equals(0));
        expect(glow.opacity, equals(0));

        avatar.setColor(const Color(0xFFFFFFFF));

        expect(avatar.opacity, equals(1));
        expect(glow.opacity, equals(1));
        for (final layer in _layersOf(avatar)) {
          expect(layer.paint.color, equals(const Color(0xFFFFFFFF)));
        }
      },
    );

    testWithGame<FlameGame>(
      'draws the zone five glow behind every layer',
      FlameGame.new,
      (game) async {
        final avatar = await _loadAvatar(game);
        avatar.add(ZoneFiveGlowComponent(avatarSize: avatar.size));
        await game.ensureAdd(avatar);

        final drawOrder = avatar.children.toList();

        expect(drawOrder.first, isA<ZoneFiveGlowComponent>());
        expect(
          drawOrder.skip(1).whereType<AvatarLayerComponent>(),
          hasLength(AvatarLayer.values.length),
        );
      },
    );
  });
}
