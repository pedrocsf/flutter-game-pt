import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

class ZoneFiveGlowComponent extends PositionComponent
    implements OpacityProvider {
  ZoneFiveGlowComponent({required Vector2 avatarSize})
    : super(
        size: avatarSize * _glowScale,
        position: avatarSize / 2,
        anchor: Anchor.center,
        priority: _glowPriority,
      );

  static const _glowColor = ui.Color(0xFFFFB000);
  static const _glowScale = 1.6;
  static const _glowPriority = -1;
  static const _glowAlpha = .55;
  static const _pulseScale = 1.12;
  static const _pulseDuration = .9;

  double _opacity = 1;

  @override
  double get opacity => _opacity;

  @override
  set opacity(double value) {
    _opacity = value;
  }

  @override
  void onLoad() {
    add(
      ScaleEffect.to(
        Vector2.all(_pulseScale),
        EffectController(
          duration: _pulseDuration,
          reverseDuration: _pulseDuration,
          infinite: true,
          curve: Curves.easeInOut,
          reverseCurve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void render(ui.Canvas canvas) {
    final radius = size.x / 2;
    final center = ui.Offset(radius, size.y / 2);
    final paint = ui.Paint()
      ..shader = ui.Gradient.radial(center, radius, [
        _glowColor.withValues(alpha: _glowAlpha * _opacity),
        _glowColor.withValues(alpha: 0),
      ]);
    canvas.drawCircle(center, radius, paint);
  }
}
