import 'package:flame/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/avatar/avatar.dart';

void main() {
  group('ZoneFiveGlowComponent', () {
    testWithGame<FlameGame>(
      'is drawn behind the avatar and centered on it',
      FlameGame.new,
      (game) async {
        final glow = ZoneFiveGlowComponent(avatarSize: Vector2.all(64));
        await game.ensureAdd(glow);

        expect(glow.priority, lessThan(0));
        expect(glow.position, equals(Vector2.all(32)));
        expect(glow.size.x, greaterThan(64));
      },
    );

    testWithGame<FlameGame>('pulses in a loop', FlameGame.new, (game) async {
      final glow = ZoneFiveGlowComponent(avatarSize: Vector2.all(64));
      await game.ensureAdd(glow);

      game.update(.45);
      expect(glow.scale.x, greaterThan(1));

      game.update(.45);
      expect(glow.scale.x, closeTo(1.12, .01));

      game.update(1.8);
      expect(glow.scale.x, closeTo(1.12, .01));
    });
  });
}
