import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';

class _Target extends PositionComponent {
  _Target() : super(position: Vector2(100, 200), size: Vector2.all(32));
}

void main() {
  group('LifeLostIndicator', () {
    testWithFlameGame('shows the minus one label above the origin', (
      game,
    ) async {
      final indicator = LifeLostIndicator(origin: Vector2(50, 80));
      await game.ensureAdd(indicator);

      expect(indicator.text, '-1');
      expect(indicator.position.x, 50);
      expect(indicator.position.y, lessThan(80));
    });

    testWithFlameGame('rises while it fades', (game) async {
      final indicator = LifeLostIndicator(origin: Vector2(50, 80));
      await game.ensureAdd(indicator);
      final startY = indicator.position.y;

      game.update(LifeLostIndicator.lifetime / 2);

      expect(indicator.position.y, lessThan(startY));
      expect(indicator.progress, closeTo(.5, .001));
    });

    testWithFlameGame('removes itself when the lifetime is over', (game) async {
      final indicator = LifeLostIndicator(origin: Vector2.zero());
      await game.ensureAdd(indicator);

      game
        ..update(LifeLostIndicator.lifetime + .1)
        ..processLifecycleEvents();

      expect(indicator.isMounted, isFalse);
    });

    testWithFlameGame('follows the target when one is given', (game) async {
      final target = _Target();
      await game.ensureAddAll([target]);
      final indicator = LifeLostIndicator(
        origin: Vector2.zero(),
        followTarget: target,
      );
      await game.ensureAdd(indicator);

      target.x = 300;
      game.update(.1);

      expect(indicator.position.x, 300 + target.width / 2);
    });
  });
}
