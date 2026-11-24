import 'package:flame/components.dart';
import 'package:moovz_dash/game/entities/item_type.dart';

class ItemAnimationSheet {
  const ItemAnimationSheet(
    this.file,
    this.amount,
    this.amountPerRow, {
    this.stepTime = defaultStepTime,
  });

  static const defaultStepTime = .042;
  static const frameSize = 64.0;

  final String file;
  final int amount;
  final int amountPerRow;
  final double stepTime;

  SpriteAnimationData toAnimationData({double textureSize = frameSize}) {
    return SpriteAnimationData.sequenced(
      amount: amount,
      amountPerRow: amountPerRow,
      textureSize: Vector2.all(textureSize),
      stepTime: stepTime,
    );
  }
}

const Map<ItemType, ItemAnimationSheet> itemAnimationSheets = {
  ItemType.medal: ItemAnimationSheet('anim/spritesheet_item_medal.png', 48, 8),
  ItemType.zoneFive: ItemAnimationSheet(
    'anim/spritesheet_item_zonefive.png',
    30,
    6,
  ),
  ItemType.extraLife: ItemAnimationSheet(
    'anim/spritesheet_item_extra_life.png',
    8,
    8,
    stepTime: .1,
  ),
};
