import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:moovz_dash/game/moovz_dash_game.dart';

class TreeSign extends TextComponent with HasGameRef<MoovzDashGame> {
  TreeSign({super.position})
    : super(
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xffffffff),
            fontSize: 24,
            fontFamily: 'DM Sans',
            package: 'app_ui',
          ),
        ),
      );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    final currentLevel = gameRef.state.currentLevel;
    text = 'TREINO $currentLevel';
  }
}
