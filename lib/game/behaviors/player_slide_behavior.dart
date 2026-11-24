import 'dart:async';

import 'package:flame_behaviors/flame_behaviors.dart';
import 'package:moovz_dash/game/game.dart';

class PlayerSlideBehavior extends Behavior<Player> {
  static const slideDuration = 0.6;
  static const slideCooldown = 0.15;

  double _remainingTime = 0;
  double _cooldownTime = 0;
  bool _isSliding = false;

  bool get isSliding => _isSliding;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    parent.gameRef.addSlideListener(_handleSlideInput);
  }

  @override
  void onRemove() {
    super.onRemove();

    parent.gameRef.removeSlideListener(_handleSlideInput);
  }

  bool get _canStartSlide {
    return !_isSliding &&
        _cooldownTime <= 0 &&
        !parent.isDead &&
        !parent.isPlayerTeleporting &&
        !parent.isPlayerRespawning &&
        !parent.isGoingToGameOver &&
        parent.walking &&
        parent.isOnGround &&
        !parent.jumping;
  }

  void _handleSlideInput() {
    if (_canStartSlide) startSlide();
  }

  void startSlide() {
    _isSliding = true;
    _remainingTime = slideDuration;
    parent.enterSlideHitbox();
    parent.stateBehavior.state = parent.hasZoneFive
        ? DashState.zoneFiveSlide
        : DashState.slide;
  }

  bool endSlide({bool force = false}) {
    if (!_isSliding) return true;
    if (!force && !parent.canStandUp) return false;

    _isSliding = false;
    _cooldownTime = slideCooldown;
    parent.exitSlideHitbox();
    _restoreMovementState();
    return true;
  }

  void _restoreMovementState() {
    if (parent.walking) {
      parent.setRunningState();
      return;
    }
    parent.setIdleState();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_cooldownTime > 0) _cooldownTime -= dt;
    if (!_isSliding || parent.isDead || parent.isGoingToGameOver) return;

    _remainingTime -= dt;
    if (_remainingTime <= 0) endSlide();
  }
}
