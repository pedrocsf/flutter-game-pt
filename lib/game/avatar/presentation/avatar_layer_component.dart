import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

class AvatarLayerComponent extends PositionComponent with HasPaint {
  AvatarLayerComponent({
    required this.animation,
    required this._ticker,
    required Paint paint,
    super.size,
  }) {
    this.paint = paint;
  }

  final SpriteAnimation animation;
  final SpriteAnimationTicker _ticker;

  int get frameIndex => _ticker.currentIndex;

  Sprite get currentSprite => animation.frames[frameIndex].sprite;

  @override
  void render(Canvas canvas) {
    currentSprite.render(canvas, size: size, overridePaint: paint);
  }
}
