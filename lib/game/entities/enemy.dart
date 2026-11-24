import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';
import 'package:leap/leap.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:pathxp/pathxp.dart';

enum EnemyType {
  cramp,
  soreness,
  icePack,
  fatigueHourglass,
  lazyCloud,
  bandage,
  lowBar,
  unknown;

  static const Map<String, EnemyType> _valuesByName = {
    'Cramp': EnemyType.cramp,
    'Soreness': EnemyType.soreness,
    'IcePack': EnemyType.icePack,
    'FatigueHourglass': EnemyType.fatigueHourglass,
    'LazyCloud': EnemyType.lazyCloud,
    'Bandage': EnemyType.bandage,
    'LowBar': EnemyType.lowBar,
    'Beetle': EnemyType.cramp,
    'Ant': EnemyType.soreness,
    'Grasshopper': EnemyType.icePack,
    'Bee': EnemyType.fatigueHourglass,
    'Butterfly': EnemyType.lazyCloud,
    'Firefly': EnemyType.bandage,
  };

  static EnemyType fromValue(String value) =>
      _valuesByName[value] ?? EnemyType.unknown;
}

class EnemySpriteSheet {
  const EnemySpriteSheet(
    this.file,
    this.amount,
    this.amountPerRow, {
    this.stepTime = defaultStepTime,
  });

  static const defaultStepTime = .04;

  final String file;
  final int amount;
  final int amountPerRow;
  final double stepTime;
}

const Map<EnemyType, EnemySpriteSheet> enemySpriteSheets = {
  EnemyType.cramp: EnemySpriteSheet('anim/spritesheet_enemy_cramp.png', 16, 8),
  EnemyType.soreness: EnemySpriteSheet(
    'anim/spritesheet_enemy_soreness.png',
    12,
    6,
  ),
  EnemyType.icePack: EnemySpriteSheet(
    'anim/spritesheet_enemy_ice_pack.png',
    22,
    11,
  ),
  EnemyType.fatigueHourglass: EnemySpriteSheet(
    'anim/spritesheet_enemy_fatigue_hourglass.png',
    14,
    7,
  ),
  EnemyType.lazyCloud: EnemySpriteSheet(
    'anim/spritesheet_enemy_lazy_cloud.png',
    16,
    8,
  ),
  EnemyType.bandage: EnemySpriteSheet(
    'anim/spritesheet_enemy_bandage.png',
    32,
    8,
  ),
  EnemyType.lowBar: EnemySpriteSheet(
    'anim/spritesheet_obstacle_low_bar.png',
    4,
    4,
    stepTime: .15,
  ),
};

class Enemy extends PhysicalEntity<MoovzDashGame> {
  Enemy({required this.tiledObject, this.enemyDamage = 1})
    : type = _typeOf(tiledObject),
      super(
        collisionType: CollisionType.standard,
        static: _isFlying(tiledObject) || _isStaticObstacle(tiledObject),
      );

  static const lowBarHitboxWidth = 64.0;
  static const lowBarHitboxHeight = 20.0;
  static const lowBarFrameSize = 64.0;
  static const lowBarFrameOffsetY = -40.0;

  static EnemyType _typeOf(TiledObject object) {
    final name = (object.properties.byName['Type'] as StringProperty?)?.value;
    return EnemyType.fromValue(name ?? '');
  }

  static bool _isFlying(TiledObject object) {
    return object.properties.byName['Fly']?.value as bool? ?? false;
  }

  static bool _isLow(TiledObject object) {
    return object.properties.byName['Low']?.value as bool? ?? false;
  }

  static bool _isStaticObstacle(TiledObject object) {
    return _isLow(object) || _typeOf(object) == EnemyType.lowBar;
  }

  final int enemyDamage;
  late final EnemyType type;
  late final TiledObject tiledObject;

  @override
  int get priority => 1;

  bool get isLowBar => type == EnemyType.lowBar;

  bool get isLowObstacle => _isStaticObstacle(tiledObject);

  @override
  Future<void> onLoad() async {
    position = Vector2(tiledObject.x, tiledObject.y);

    if (isLowBar) {
      size = Vector2(lowBarHitboxWidth, lowBarHitboxHeight);
      await _addSprite(
        size: Vector2.all(lowBarFrameSize),
        anchor: Anchor.topLeft,
        spritePosition: Vector2(0, lowBarFrameOffsetY),
      );
      return super.onLoad();
    }

    size = Vector2.all(gameRef.tileSize * .5);

    if (!isLowObstacle) _addPathBehavior();

    await _addSprite(
      size: Vector2.all(gameRef.tileSize),
      anchor: Anchor.center,
      spritePosition: size / 2 - Vector2(0, size.y / 2),
    );

    return super.onLoad();
  }

  void _addPathBehavior() {
    final path =
        (tiledObject.properties.byName['Path'] as StringProperty?)?.value;
    if (path == null) return;

    add(FollowPathBehavior(Pathxp(path)));
  }

  Future<void> _addSprite({
    required Vector2 size,
    required Anchor anchor,
    required Vector2 spritePosition,
  }) async {
    final sheet = enemySpriteSheets[type];

    if (sheet == null) {
      add(
        RectangleComponent(
          size: size,
          paint: Paint()..color = Colors.pink,
          anchor: anchor,
          position: spritePosition,
        ),
      );
      return;
    }

    final animation = await gameRef.loadSpriteAnimation(
      sheet.file,
      SpriteAnimationData.sequenced(
        amount: sheet.amount,
        amountPerRow: sheet.amountPerRow,
        textureSize: Vector2.all(64),
        stepTime: sheet.stepTime,
      ),
    );

    add(
      SpriteAnimationComponent(
        size: size,
        animation: animation,
        anchor: anchor,
        position: spritePosition,
      ),
    );
  }
}
