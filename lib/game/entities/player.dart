import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/widgets.dart';
import 'package:leap/leap.dart';
import 'package:moovz_dash/audio/audio.dart';
import 'package:moovz_dash/game/game.dart';

class Player extends JumperCharacter<MoovzDashGame> {
  Player({
    required this.levelSize,
    required this.cameraViewport,
    super.health = initialHealth,
  });

  static const initialHealth = 1;
  static const jumpImpulse = .6;
  static const slideHeightRatio = .5;
  static const hitInvincibilityDuration = 1.5;
  static const blinkInterval = .1;
  static const blinkDimmedOpacity = .25;
  static const opaque = 1.0;
  static const stuckTimeout = 1.0;
  static const gameOverDelay = 1.4;
  static const _tileEdgeTolerance = .001;

  final Vector2 levelSize;
  final Vector2 cameraViewport;
  late Vector2 spawn;
  late List<Vector2> respawnPoints;
  late final PlayerCameraAnchor cameraAnchor;
  late final PlayerStateBehavior stateBehavior =
      findBehavior<PlayerStateBehavior>();
  late final PlayerSlideBehavior slideBehavior = PlayerSlideBehavior();
  late final double standingHeight;

  bool hasZoneFive = false;
  bool isPlayerInvincible = false;
  bool isPlayerTeleporting = false;
  bool isPlayerRespawning = false;

  double? _gameOverTimer;
  double _hitInvincibilityTimer = 0;

  double? _stuckTimer;
  double _dashPosition = 0;

  bool get isGoingToGameOver => _gameOverTimer != null;

  bool get isHitInvincible => _hitInvincibilityTimer > 0;

  bool get _isImmuneToEnemies =>
      isPlayerInvincible ||
      isHitInvincible ||
      isPlayerRespawning ||
      isPlayerTeleporting;

  bool get isSliding => slideBehavior.isSliding;

  bool get canStandUp {
    final tiles = gameRef.leapMap.groundTiles;
    if (tiles.isEmpty) return true;

    final headTop = bottom - standingHeight;
    final firstColumn = math.max(0, (left / tileSize).floor());
    final lastColumn = math.min(
      tiles.length - 1,
      ((right - _tileEdgeTolerance) / tileSize).floor(),
    );
    final firstRow = math.max(0, (headTop / tileSize).floor());
    final lastRow = math.min(
      tiles.first.length - 1,
      ((top - _tileEdgeTolerance) / tileSize).floor(),
    );

    for (var column = firstColumn; column <= lastColumn; column++) {
      for (var row = firstRow; row <= lastRow; row++) {
        final tile = tiles[column][row];
        if (tile != null && _blocksStandingUp(tile, headTop)) return false;
      }
    }
    return true;
  }

  bool _blocksStandingUp(PhysicalEntity tile, double headTop) {
    return tile.collisionType == CollisionType.tilemapGround &&
        !tile.tags.contains('platform') &&
        tile.relativeTop(this) < top &&
        tile.bottom > headTop;
  }

  void enterSlideHitbox() {
    final slideHeight = standingHeight * slideHeightRatio;
    y += height - slideHeight;
    size.y = slideHeight;
    stateBehavior.syncAvatarPositions();
  }

  void exitSlideHitbox() {
    y -= standingHeight - height;
    size.y = standingHeight;
    stateBehavior.syncAvatarPositions();
  }

  @override
  int get priority => 1;

  void jumpEffects() {
    final jumpSound = hasZoneFive ? Sfx.zoneFiveJump : Sfx.jump;
    gameRef.audioController.playSfx(jumpSound);

    final newJumpState = hasZoneFive ? DashState.zoneFiveJump : DashState.jump;
    stateBehavior.state = newJumpState;
  }

  void doubleJumpEffects() {
    gameRef.audioController.playSfx(Sfx.zoneFiveJump);
    stateBehavior.state = DashState.zoneFiveDoubleJump;
  }

  @override
  set walking(bool value) {
    if (!value) slideBehavior.endSlide(force: true);

    if (!super.walking && value) {
      setRunningState();
    } else if (super.walking && !value) {
      setIdleState();
    }

    super.walking = value;
  }

  void setRunningState() {
    if (isSliding) return;

    final behavior = stateBehavior;
    if (behavior.state != DashState.running &&
        behavior.state != DashState.zoneFiveRunning) {
      final newRunState = hasZoneFive
          ? DashState.zoneFiveRunning
          : DashState.running;
      if (behavior.state != newRunState) {
        behavior.state = newRunState;
      }
    }
  }

  void setIdleState() {
    stateBehavior.state = hasZoneFive ? DashState.zoneFiveIdle : DashState.idle;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    size = Vector2.all(gameRef.tileSize * .5);
    standingHeight = size.y;
    walkSpeed = gameRef.tileSize * gameRef.difficulty.playerSpeed;
    minJumpImpulse = world.gravity * jumpImpulse;
    cameraAnchor = PlayerCameraAnchor(
      cameraViewport: cameraViewport,
      levelSize: levelSize,
      showCameraBounds: gameRef.inMapTester,
    );

    add(cameraAnchor);
    add(PlayerControllerBehavior());
    add(slideBehavior);
    add(PlayerStateBehavior());

    gameRef.camera.follow(cameraAnchor);

    loadSpawnPoint();
    loadRespawnPoints();
  }

  void loadRespawnPoints() {
    final respawnGroup = gameRef.leapMap.getTileLayer<ObjectGroup>('respawn');
    respawnPoints = [
      ...respawnGroup.objects.map((object) => Vector2(object.x, object.y)),
    ];
  }

  void loadSpawnPoint() {
    final spawnGroup = gameRef.leapMap.getTileLayer<ObjectGroup>('spawn');
    for (final object in spawnGroup.objects) {
      position = Vector2(object.x, object.y);
      spawn = position.clone();
    }
  }

  void addPowerUp() {
    hasZoneFive = true;

    if (stateBehavior.state == DashState.idle) {
      stateBehavior.state = DashState.zoneFiveIdle;
    } else if (stateBehavior.state == DashState.running) {
      stateBehavior.state = DashState.zoneFiveRunning;
    } else if (stateBehavior.state == DashState.slide) {
      stateBehavior.state = DashState.zoneFiveSlide;
    }
  }

  void removePowerUp() {
    hasZoneFive = false;

    final newState = switch (stateBehavior.state) {
      DashState.zoneFiveIdle => DashState.idle,
      DashState.zoneFiveRunning => DashState.running,
      DashState.zoneFiveSlide => DashState.slide,
      DashState.zoneFiveJump || DashState.zoneFiveDoubleJump => DashState.jump,
      final other => other,
    };
    stateBehavior.state = newState;
  }

  void collectItem(ItemType type) {
    switch (type) {
      case ItemType.energy:
        gameRef.audioController.playSfx(Sfx.energyPickup);
        gameRef.gameBloc.add(GameScoreIncreased(by: type.points));
      case ItemType.medal:
        gameRef.audioController.playSfx(Sfx.medalPickup);
        gameRef.gameBloc.add(GameScoreIncreased(by: type.points));
      case ItemType.zoneFive:
        addPowerUp();
        gameRef.audioController.playSfx(Sfx.zoneFivePowerup);
      case ItemType.extraLife:
        gameRef.audioController.playSfx(Sfx.medalPickup);
        _collectExtraLife();
    }

    if (type.isSpecial) {
      gameRef.gameBloc.add(GameSpecialItemCollected(type));
    }
  }

  void _collectExtraLife() {
    if (gameRef.state.lives >= GameState.maxLives) {
      gameRef.gameBloc.add(
        const GameScoreIncreased(by: ItemType.extraLifeFullLivesPoints),
      );
      return;
    }
    gameRef.gameBloc.add(const GameLifeGained());
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_gameOverTimer != null) {
      _gameOverTimer = _gameOverTimer! - dt;
      if (_gameOverTimer! <= 0) {
        _gameOverTimer = null;
        gameRef.gameOver();
      }
      return;
    }

    _updateHitInvincibility(dt);
    _checkPlayerStuck(dt);

    if (isGoingToGameOver || isPlayerTeleporting) return;

    if (_hasFallenOutOfMap) {
      _takeHit(deathState: DashState.deathPit, onSurvive: respawn);
      return;
    }

    if ((gameRef.isLastSection && x >= gameRef.leapMap.width - tileSize) ||
        (!gameRef.isLastSection &&
            x >= gameRef.leapMap.width - gameRef.tileSize * 15)) {
      sectionCleared();
      return;
    }

    if (isDead) {
      return _animateToGameOver();
    }

    if ((collisionInfo.downCollision?.tags.contains('hazard') ?? false) &&
        !isPlayerInvincible) {
      _takeHit(deathState: DashState.deathPit, onSurvive: respawn);
      return;
    }

    final collisions = collisionInfo.otherCollisions ?? const [];

    if (collisions.isEmpty) return;

    for (final collision in collisions) {
      if (collision is Item) {
        collectItem(collision.type);
        gameRef.world.add(
          ItemEffect(
            type: collision.type,
            position: collision.position.clone(),
          ),
        );
        collision.removeFromParent();
      }

      if (collision is Enemy && !_isImmuneToEnemies) {
        _takeHit(
          deathState: DashState.deathFaint,
          onSurvive: _startHitInvincibility,
          indicatorFollowsPlayer: true,
        );
        return;
      }
    }
  }

  bool get _hasFallenOutOfMap {
    if (isPlayerInvincible || isPlayerTeleporting || isPlayerRespawning) {
      return false;
    }
    return y > gameRef.leapMap.height + gameRef.tileSize;
  }

  void _takeHit({
    required DashState deathState,
    required VoidCallback onSurvive,
    bool indicatorFollowsPlayer = false,
  }) {
    if (hasZoneFive) {
      removePowerUp();
      onSurvive();
      return;
    }

    final wasLastLife = gameRef.state.lives <= 1;
    _loseLife(indicatorFollowsPlayer: indicatorFollowsPlayer);

    if (wasLastLife) {
      _animateToGameOver(deathState);
      return;
    }
    onSurvive();
  }

  void _loseLife({required bool indicatorFollowsPlayer}) {
    gameRef.gameBloc.add(const GameLifeLost());
    gameRef.world.add(
      LifeLostIndicator(
        origin: Vector2(x + width / 2, y),
        followTarget: indicatorFollowsPlayer ? this : null,
      ),
    );
  }

  void _startHitInvincibility() {
    _hitInvincibilityTimer = hitInvincibilityDuration;
  }

  void _clearHitInvincibility() {
    if (!isHitInvincible) return;
    _hitInvincibilityTimer = 0;
    stateBehavior.setOpacity(opaque);
  }

  void _updateHitInvincibility(double dt) {
    if (!isHitInvincible || isPlayerTeleporting) return;

    _hitInvincibilityTimer -= dt;
    if (!isHitInvincible) {
      _hitInvincibilityTimer = 0;
      stateBehavior.setOpacity(opaque);
      return;
    }

    final elapsed = hitInvincibilityDuration - _hitInvincibilityTimer;
    final isDimmedPhase = (elapsed / blinkInterval).floor().isEven;
    stateBehavior.setOpacity(isDimmedPhase ? blinkDimmedOpacity : opaque);
  }

  void _checkPlayerStuck(double dt) {
    final currentDashPosition = position.x;
    final isPlayerStopped = currentDashPosition == _dashPosition;
    // Player is set as walking but is not moving.
    if (walking && isPlayerStopped) {
      _stuckTimer ??= stuckTimeout;
      _stuckTimer = _stuckTimer! - dt;
      if (_stuckTimer! <= 0) {
        _stuckTimer = null;
        _takeStuckHit();
      }
    } else {
      _stuckTimer = null;
    }
    _dashPosition = currentDashPosition;
  }

  void _takeStuckHit() {
    if (isPlayerTeleporting || isPlayerRespawning || isPlayerInvincible) return;
    _takeHit(deathState: DashState.deathFaint, onSurvive: respawn);
  }

  void _animateToGameOver([DashState deathState = DashState.deathFaint]) {
    _clearHitInvincibility();
    stateBehavior.state = deathState;
    super.walking = false;
    _gameOverTimer = gameOverDelay;
  }

  void respawn() {
    // Get closest value to gridX and gridY in respawnPoints.
    final respawnPointsBehind = respawnPoints.where((point) {
      return point.x < position.x;
    });

    Vector2 closestRespawn;
    if (respawnPointsBehind.isEmpty) {
      closestRespawn = spawn;
    } else {
      closestRespawn = respawnPointsBehind.reduce((a, b) {
        return (a - position).length2 < (b - position).length2 ? a : b;
      });
    }

    _clearHitInvincibility();
    isPlayerRespawning = true;
    isPlayerInvincible = true;
    walking = false;
    stateBehavior.fadeOut();
    add(
      MoveToEffect(
        closestRespawn.clone(),
        EffectController(curve: Curves.easeInOut, startDelay: .2, duration: .8),
      ),
    );
    stateBehavior.fadeIn(
      onComplete: () {
        isPlayerRespawning = false;
        isPlayerInvincible = false;
        walking = true;
      },
    );
  }

  void spritePaintColor(Color color) {
    stateBehavior.updateSpritePaintColor(color);
  }

  void sectionCleared() {
    isPlayerTeleporting = true;
    gameRef.sectionCleared();
  }
}
