import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:moovz_dash/game/avatar/domain/avatar_animation.dart';
import 'package:moovz_dash/game/avatar/domain/avatar_appearance.dart';
import 'package:moovz_dash/game/avatar/domain/avatar_layer.dart';
import 'package:moovz_dash/game/avatar/presentation/avatar_layer_component.dart';

class AvatarSpriteComponent extends PositionComponent
    implements OpacityProvider {
  AvatarSpriteComponent._({
    required Vector2 size,
    required this._ticker,
    required List<AvatarLayerComponent> layers,
  }) : _layers = layers,
       super(size: size, anchor: Anchor.center, children: layers);

  static const layerFilterQuality = FilterQuality.medium;

  final SpriteAnimationTicker _ticker;
  final List<AvatarLayerComponent> _layers;
  double _opacity = 1;

  static Future<AvatarSpriteComponent> load({
    required FlameGame game,
    required AvatarAnimation animation,
    required AvatarAppearance appearance,
    required Vector2 size,
  }) async {
    final spriteAnimations = await Future.wait(
      AvatarLayer.values.map(
        (layer) => game.loadSpriteAnimation(
          appearance.assetPath(layer, animation),
          _spriteData(animation),
        ),
      ),
    );
    final ticker = spriteAnimations.first.createTicker();
    final layers = [
      for (final (index, layer) in AvatarLayer.values.indexed)
        AvatarLayerComponent(
          animation: spriteAnimations[index],
          ticker: ticker,
          size: size.clone(),
          paint: _layerPaint(appearance.styleOf(layer).tint),
        ),
    ];
    return AvatarSpriteComponent._(size: size, ticker: ticker, layers: layers);
  }

  static SpriteAnimationData _spriteData(AvatarAnimation animation) {
    return SpriteAnimationData.sequenced(
      amount: animation.frameCount,
      stepTime: avatarStepTime,
      textureSize: Vector2.all(avatarFrameSize),
      loop: animation.loop,
    );
  }

  static Paint _layerPaint(Color? tint) {
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = layerFilterQuality;
    if (tint == null) return paint;
    return paint..colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
  }

  List<AvatarLayerComponent> get layers => List.unmodifiable(_layers);

  int get frameIndex => _ticker.currentIndex;

  @override
  double get opacity => _opacity;

  @override
  set opacity(double value) {
    _opacity = value;
    for (final child in children.whereType<OpacityProvider>()) {
      child.opacity = value;
    }
  }

  @override
  void update(double dt) {
    _ticker.update(dt);
  }

  void setColor(Color color) {
    for (final layer in _layers) {
      layer.paint.color = color;
    }
    opacity = color.a;
  }

  void reset() {
    _ticker.reset();
  }
}
