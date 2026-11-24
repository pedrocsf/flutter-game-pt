import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:moovz_dash/game/moovz_dash_game.dart';

class CameraBounds extends PositionComponent {
  CameraBounds({
    required this.reference,
    required this.bound,
    this.showBounds = false,
  });

  final PositionComponent reference;
  final double bound;
  final bool showBounds;

  late final Vector2 referenceOffset;

  double translateValue = 0;
  double translatedValue = 0;

  void snapToReference() {
    position
      ..x = reference.position.x + referenceOffset.x
      ..y = reference.position.y + referenceOffset.y;
    translateValue = 0;
    translatedValue = 0;
  }

  void _updatePosition(double dt) {
    position.x = reference.position.x + referenceOffset.x;

    final playerPosition = reference.position.y + referenceOffset.y;
    final difference = playerPosition - position.y;
    if (difference.abs() > bound) {
      translateValue = difference;
    }

    if (translateValue.abs() > 0) {
      final translationDifference =
          (translateValue.abs() - translatedValue.abs()) / translateValue.abs();
      var speed = 1.0 - translationDifference;
      speed = 1 - speed * speed * speed * speed;

      final step = (800 * speed) * dt * translateValue.sign;

      position.y += step;
      translatedValue += step.abs();

      if (translateValue.abs() - translatedValue.abs() < 10) {
        translateValue = 0;
        translatedValue = 0;
      }
    }
  }

  @override
  void onMount() {
    super.onMount();

    referenceOffset = Vector2(reference.size.x, reference.size.y);
    position.y = reference.position.y + referenceOffset.y;

    _updatePosition(0);

    if (showBounds) {
      const referenceLine = 150.0;
      add(
        RectangleComponent(
          position: Vector2(-referenceLine / 2, -bound),
          size: Vector2(referenceLine, 2),
          paint: Paint()..color = Colors.red,
        ),
      );

      add(
        RectangleComponent(
          position: Vector2(-referenceLine / 2, 0),
          size: Vector2(referenceLine, 2),
          paint: Paint()..color = Colors.green,
        ),
      );

      add(
        RectangleComponent(
          position: Vector2(-referenceLine / 2, bound),
          size: Vector2(referenceLine, 2),
          paint: Paint()..color = Colors.red,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    _updatePosition(dt);
  }
}

class PlayerCameraAnchor extends Component
    with ParentIsA<PositionComponent>, HasGameRef<MoovzDashGame>
    implements ReadOnlyPositionProvider {
  PlayerCameraAnchor({
    required this.levelSize,
    required this.cameraViewport,
    this.showCameraBounds = false,
  });

  Vector2 levelSize;
  final Vector2 cameraViewport;
  final Vector2 _anchor = Vector2.zero();
  late final CameraBounds _bounds;
  final bool showCameraBounds;

  static const _playerScreenXRatio = 0.3;
  static const _playerScreenYRatio = 0.65;

  Vector2 get _cameraMin => cameraViewport / 2;

  Vector2 get _cameraMax => Vector2(
    max(levelSize.x - cameraViewport.x / 2, cameraViewport.x / 2),
    max(levelSize.y - cameraViewport.y / 2, cameraViewport.y / 2),
  );

  double get _cameraXOffset => cameraViewport.x * (0.5 - _playerScreenXRatio);
  double get _cameraYOffset => cameraViewport.y * (_playerScreenYRatio - 0.5);

  @override
  Vector2 get position => _anchor;

  void _setAnchor(double x, double y) {
    _anchor
      ..x = (x + _cameraXOffset).clamp(_cameraMin.x, _cameraMax.x)
      ..y = (y - _cameraYOffset).clamp(_cameraMin.y, _cameraMax.y);
  }

  void snapToPlayer({required Vector2 levelSize}) {
    this.levelSize = levelSize;
    _bounds.snapToReference();
    _setAnchor(_bounds.position.x, _bounds.position.y);
  }

  @override
  void onMount() {
    super.onMount();

    _bounds = CameraBounds(
      reference: parent,
      bound: 128,
      showBounds: showCameraBounds,
    );
    gameRef.world.add(_bounds);

    final value = parent.position.clone();
    _setAnchor(value.x, value.y);
  }

  @override
  void update(double dt) {
    super.update(dt);

    _setAnchor(_bounds.position.x, _bounds.position.y);
  }
}
