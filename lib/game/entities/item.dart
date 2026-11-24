import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';
import 'package:leap/leap.dart';
import 'package:moovz_dash/game/entities/item_animation_sheet.dart';
import 'package:moovz_dash/game/entities/item_type.dart';
import 'package:moovz_dash/game/moovz_dash_game.dart';

class Item extends PhysicalEntity<MoovzDashGame> {
  Item({required this.tiledObject})
    : super(static: true, collisionType: CollisionType.standard);

  late final ItemType type;
  late final TiledObject tiledObject;

  @override
  int get priority => 2;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    type = ItemType.fromType(
      (tiledObject.properties.byName['Type'] as StringProperty?)?.value,
    );

    size = Vector2.all(gameRef.tileSize);
    position = Vector2(tiledObject.x, tiledObject.y);

    final sheet = itemAnimationSheets[type];
    if (sheet != null) {
      final animation = await gameRef.loadSpriteAnimation(
        sheet.file,
        sheet.toAnimationData(textureSize: gameRef.tileSize),
      );
      add(SpriteAnimationComponent(animation: animation, size: size));
    } else {
      add(
        SpriteComponent(
          size: size,
          sprite: gameRef.itemsSpritesheet.getSpriteById(
            (tiledObject.gid ?? 0) - gameRef.itemsTileset.firstGid!,
          ),
          children: [
            SequenceEffect([
              MoveEffect.by(
                -Vector2(0, gameRef.tileSize / 2),
                CurvedEffectController(.8, Curves.easeIn),
              ),
              MoveEffect.by(
                Vector2(0, gameRef.tileSize / 2),
                CurvedEffectController(.8, Curves.easeOut),
              ),
            ], infinite: true),
          ],
        ),
      );
    }
  }
}
