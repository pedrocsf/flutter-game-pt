import 'dart:async';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/sprite.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/game/avatar/avatar.dart';

class _MockImages extends Mock implements Images {}

const _size = 64.0;
const _shirtTint = Color(0xFF2050C0);

Duration _steps(double amount) {
  final seconds = avatarStepTime * amount;
  return Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );
}

String _pathOf(AvatarLayer layer, AvatarAnimation animation) {
  return AvatarAnimationWidget.assetPathOf(
    const AvatarAppearance.standard(),
    layer,
    animation,
  );
}

Future<Images> _imagesFor(
  WidgetTester tester,
  List<AvatarAnimation> animations,
) async {
  final images = Images(prefix: '');
  await tester.runAsync(() async {
    for (final animation in animations) {
      for (final layer in AvatarLayer.values) {
        images.add(
          _pathOf(layer, animation),
          await generateImage(
            (avatarFrameSize * animation.frameCount).toInt(),
            avatarFrameSize.toInt(),
          ),
        );
      }
    }
  });
  addTearDown(images.clearCache);
  return images;
}

Future<void> _pumpAvatar(
  WidgetTester tester, {
  required Images images,
  required AvatarAnimation animation,
  AvatarAppearance appearance = const AvatarAppearance.standard(),
}) async {
  await tester.pumpWidget(
    Center(
      child: AvatarAnimationWidget(
        animation: animation,
        appearance: appearance,
        size: _size,
        images: images,
      ),
    ),
  );
  await tester.pump();
}

List<AvatarLayerPainter> _painters(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(AvatarAnimationWidget),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((customPaint) => customPaint.painter)
      .whereType<AvatarLayerPainter>()
      .toList();
}

Set<int> _frameIndexes(WidgetTester tester) {
  return _painters(
    tester,
  ).map((painter) => painter.sprite.srcPosition.x ~/ avatarFrameSize).toSet();
}

void main() {
  group('AvatarAnimationWidget', () {
    testWidgets('keeps its size with an empty box while loading', (
      tester,
    ) async {
      final images = _MockImages();
      final pending = Completer<Image>();
      when(() => images.load(any())).thenAnswer((_) => pending.future);

      await _pumpAvatar(tester, images: images, animation: AvatarAnimation.run);

      expect(_painters(tester), isEmpty);
      expect(
        tester.getSize(find.byType(AvatarAnimationWidget)),
        equals(const Size.square(_size)),
      );
    });

    testWidgets('loads every layer from the full asset path', (tester) async {
      final images = _MockImages();
      when(
        () => images.load(any()),
      ).thenAnswer((_) => Completer<Image>().future);

      await _pumpAvatar(tester, images: images, animation: AvatarAnimation.run);

      for (final layer in AvatarLayer.values) {
        verify(
          () => images.load(
            'assets/map/anim/avatar/${layer.fileName}_default_run.png',
          ),
        ).called(1);
      }
    });

    testWidgets('draws one image per layer in the AvatarLayer order', (
      tester,
    ) async {
      final images = await _imagesFor(tester, [AvatarAnimation.run]);

      await _pumpAvatar(tester, images: images, animation: AvatarAnimation.run);

      final painters = _painters(tester);
      expect(painters, hasLength(AvatarLayer.values.length));
      for (final (index, layer) in AvatarLayer.values.indexed) {
        expect(
          painters[index].sprite.image,
          same(images.fromCache(_pathOf(layer, AvatarAnimation.run))),
        );
      }
      expect(
        tester.getSize(find.byType(AvatarAnimationWidget)),
        equals(const Size.square(_size)),
      );
    });

    testWidgets('advances every layer in the same frame', (tester) async {
      final images = await _imagesFor(tester, [AvatarAnimation.run]);
      await _pumpAvatar(tester, images: images, animation: AvatarAnimation.run);

      expect(_frameIndexes(tester), equals({0}));

      await tester.pump(_steps(2.5));
      expect(_frameIndexes(tester), equals({2}));

      await tester.pump(_steps(1));
      expect(_frameIndexes(tester), equals({3}));
    });

    testWidgets('restarts from the first frame when it loops', (tester) async {
      final images = await _imagesFor(tester, [AvatarAnimation.run]);
      await _pumpAvatar(tester, images: images, animation: AvatarAnimation.run);

      await tester.pump(_steps(AvatarAnimation.run.frameCount + 1.5));

      expect(_frameIndexes(tester), equals({1}));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('stops on the last frame when it does not loop', (
      tester,
    ) async {
      const animation = AvatarAnimation.deathFaint;
      final images = await _imagesFor(tester, [animation]);
      await _pumpAvatar(tester, images: images, animation: animation);

      await tester.pump(_steps(animation.frameCount * 2.0));
      await tester.pump(_steps(animation.frameCount * 2.0));

      expect(_frameIndexes(tester), equals({animation.frameCount - 1}));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('tints only the layers that have a tint', (tester) async {
      final images = await _imagesFor(tester, [AvatarAnimation.run]);
      final appearance = const AvatarAppearance.standard().withLayer(
        AvatarLayer.shirt,
        const AvatarLayerStyle(tint: _shirtTint),
      );

      await _pumpAvatar(
        tester,
        images: images,
        animation: AvatarAnimation.run,
        appearance: appearance,
      );

      final painters = _painters(tester);
      for (final (index, layer) in AvatarLayer.values.indexed) {
        final paint = painters[index].layerPaint;
        expect(paint.filterQuality, equals(FilterQuality.medium));
        if (layer == AvatarLayer.shirt) {
          expect(
            paint.colorFilter,
            equals(const ColorFilter.mode(_shirtTint, BlendMode.modulate)),
          );
        } else {
          expect(paint.colorFilter, isNull);
        }
      }
    });

    testWidgets('loads the new animation when it changes', (tester) async {
      final images = await _imagesFor(tester, [
        AvatarAnimation.run,
        AvatarAnimation.deathFaint,
      ]);
      await _pumpAvatar(tester, images: images, animation: AvatarAnimation.run);
      await tester.pump(_steps(3.5));

      await _pumpAvatar(
        tester,
        images: images,
        animation: AvatarAnimation.deathFaint,
      );

      final painters = _painters(tester);
      for (final (index, layer) in AvatarLayer.values.indexed) {
        expect(
          painters[index].sprite.image,
          same(images.fromCache(_pathOf(layer, AvatarAnimation.deathFaint))),
        );
      }
      expect(_frameIndexes(tester), equals({0}));
    });

    testWidgets('ignores images that finish loading after dispose', (
      tester,
    ) async {
      final images = _MockImages();
      final pending = Completer<Image>();
      when(() => images.load(any())).thenAnswer((_) => pending.future);
      await _pumpAvatar(tester, images: images, animation: AvatarAnimation.run);

      await tester.pumpWidget(const SizedBox.shrink());
      final image = await tester.runAsync(generateImage);
      pending.complete(image);
      await tester.pump();

      expect(tester.takeException(), isNull);
      image!.dispose();
    });
  });

  group('AvatarLayerPainter', () {
    test('repaints only when the sprite or the paint changes', () async {
      final image = await generateImage();
      final sprite = Sprite(image);
      final paint = Paint();
      final painter = AvatarLayerPainter(sprite: sprite, layerPaint: paint);

      expect(
        painter.shouldRepaint(
          AvatarLayerPainter(sprite: sprite, layerPaint: paint),
        ),
        isFalse,
      );
      expect(
        painter.shouldRepaint(
          AvatarLayerPainter(sprite: Sprite(image), layerPaint: paint),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          AvatarLayerPainter(sprite: sprite, layerPaint: Paint()),
        ),
        isTrue,
      );
    });
  });
}
