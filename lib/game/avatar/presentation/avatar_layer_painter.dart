import 'package:flame/extensions.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/rendering.dart';

class AvatarLayerPainter extends CustomPainter {
  AvatarLayerPainter({required this.sprite, required this.layerPaint});

  final Sprite sprite;
  final Paint layerPaint;

  @override
  void paint(Canvas canvas, Size size) {
    sprite.render(canvas, size: size.toVector2(), overridePaint: layerPaint);
  }

  @override
  bool shouldRepaint(AvatarLayerPainter oldDelegate) {
    return oldDelegate.sprite != sprite || oldDelegate.layerPaint != layerPaint;
  }
}
