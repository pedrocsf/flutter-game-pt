import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

class LifeLostIndicator extends TextComponent {
  LifeLostIndicator({required Vector2 origin, this.followTarget})
    : _origin = origin.clone(),
      super(
        text: label,
        anchor: Anchor.bottomCenter,
        position: Vector2(origin.x, origin.y - headGap),
        priority: indicatorPriority,
      ) {
    textRenderer = _rendererFor(1);
  }

  static const label = '-1';
  static const indicatorPriority = 23;
  static const riseDistance = 40.0;
  static const headGap = 6.0;
  static const lifetime = .8;
  static const fontSize = 30.0;
  static const outlineOffset = 2.0;
  static const _textColor = Color(0xFFFF2D2D);
  static const _outlineColor = Color(0xFF3A0000);

  final PositionComponent? followTarget;
  final Vector2 _origin;
  double _elapsed = 0;

  double get progress => (_elapsed / lifetime).clamp(0, 1);

  @override
  void update(double dt) {
    super.update(dt);

    _elapsed += dt;
    if (_elapsed >= lifetime) {
      removeFromParent();
      return;
    }

    final target = followTarget;
    if (target != null && target.isMounted) {
      _origin.setValues(target.x + target.width / 2, target.y);
    }
    position.setValues(
      _origin.x,
      _origin.y - headGap - riseDistance * progress,
    );
    textRenderer = _rendererFor(1 - progress);
  }

  TextPaint _rendererFor(double opacity) {
    final outline = _outlineColor.withValues(alpha: opacity);
    return TextPaint(
      style: TextStyle(
        color: _textColor.withValues(alpha: opacity),
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(color: outline, offset: const Offset(-outlineOffset, 0)),
          Shadow(color: outline, offset: const Offset(outlineOffset, 0)),
          Shadow(color: outline, offset: const Offset(0, -outlineOffset)),
          Shadow(color: outline, offset: const Offset(0, outlineOffset)),
        ],
      ),
    );
  }
}
