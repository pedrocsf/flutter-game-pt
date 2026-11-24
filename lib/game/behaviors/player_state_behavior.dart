import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:moovz_dash/game/game.dart';

enum DashState {
  idle,
  running,

  zoneFiveIdle,
  zoneFiveRunning,

  deathPit,
  deathFaint,

  jump,
  zoneFiveJump,

  zoneFiveDoubleJump,

  slide,
  zoneFiveSlide,
}

class PlayerStateBehavior extends Behavior<Player> {
  DashState? _state;

  late final Map<DashState, AvatarSpriteComponent> _stateMap;

  DashState get state => _state ?? DashState.idle;

  static const _needResetStates = {
    DashState.deathPit,
    DashState.deathFaint,
    DashState.jump,
    DashState.zoneFiveJump,
    DashState.zoneFiveDoubleJump,
  };

  void updateSpritePaintColor(Color color) {
    for (final component in _stateMap.values) {
      component.setColor(color);
    }
  }

  void setOpacity(double opacity) {
    for (final component in _stateMap.values) {
      component.opacity = opacity;
    }
  }

  void syncAvatarPositions() {
    for (final component in _stateMap.values) {
      component.position = _avatarPosition(component.size);
    }
  }

  void fadeOut({VoidCallback? onComplete}) {
    final component = _stateMap[state];
    if (component != null) {
      component.add(
        OpacityEffect.fadeOut(
          EffectController(duration: .5),
          target: component,
          onComplete: onComplete,
        ),
      );
    }
  }

  void fadeIn({VoidCallback? onComplete}) {
    final component = _stateMap[state];
    if (component != null) {
      component.add(
        OpacityEffect.fadeIn(
          EffectController(duration: .5, startDelay: .8),
          target: component,
          onComplete: onComplete,
        ),
      );
    }
  }

  set state(DashState state) {
    if (state != _state) {
      final current = _stateMap[_state];

      if (current != null) {
        current.removeFromParent();

        if (_needResetStates.contains(_state)) {
          current.reset();
        }
      }

      final replacement = _stateMap[state];
      if (replacement != null) {
        parent.add(replacement);
      }
      _state = state;
    }
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    final entries = await Future.wait([
      _loadStateEntry(DashState.idle, AvatarAnimation.idle),
      _loadStateEntry(DashState.running, AvatarAnimation.run),
      _loadStateEntry(
        DashState.zoneFiveIdle,
        AvatarAnimation.idle,
        withZoneFiveGlow: true,
      ),
      _loadStateEntry(
        DashState.zoneFiveRunning,
        AvatarAnimation.run,
        withZoneFiveGlow: true,
      ),
      _loadStateEntry(DashState.deathPit, AvatarAnimation.deathPit),
      _loadStateEntry(DashState.deathFaint, AvatarAnimation.deathFaint),
      _loadStateEntry(DashState.jump, AvatarAnimation.jump),
      _loadStateEntry(
        DashState.zoneFiveJump,
        AvatarAnimation.jump,
        withZoneFiveGlow: true,
      ),
      _loadStateEntry(
        DashState.zoneFiveDoubleJump,
        AvatarAnimation.doubleJump,
        withZoneFiveGlow: true,
      ),
      _loadStateEntry(DashState.slide, AvatarAnimation.slide),
      _loadStateEntry(
        DashState.zoneFiveSlide,
        AvatarAnimation.slide,
        withZoneFiveGlow: true,
      ),
    ]);

    _stateMap = Map.fromEntries(entries);

    state = DashState.idle;
  }

  Future<MapEntry<DashState, AvatarSpriteComponent>> _loadStateEntry(
    DashState dashState,
    AvatarAnimation animation, {
    bool withZoneFiveGlow = false,
  }) async {
    final game = parent.gameRef;
    final avatar = await AvatarSpriteComponent.load(
      game: game,
      animation: animation,
      appearance: game.avatarAppearance,
      size: Vector2.all(game.tileSize),
    );
    avatar.position = _avatarPosition(avatar.size);

    if (withZoneFiveGlow) {
      avatar.add(ZoneFiveGlowComponent(avatarSize: avatar.size));
    }

    return MapEntry(dashState, avatar);
  }

  Vector2 _avatarPosition(Vector2 avatarSize) {
    final soleGap =
        avatarSize.y * (avatarFrameSize - avatarSoleBottom) / avatarFrameSize;
    return Vector2(
      parent.size.x / 2,
      parent.size.y - avatarSize.y / 2 + soleGap,
    );
  }
}
