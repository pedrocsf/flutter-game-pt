import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/audio/audio.dart';
import 'package:moovz_dash/game/game.dart';

class _MockImage extends Mock implements Image {}

class _MockImages extends Mock implements Images {}

class _MockGameBloc extends MockBloc<GameEvent, GameState>
    implements GameBloc {}

class _MockAudioController extends Mock implements AudioController {}

class _TestMoovzDashGame extends MoovzDashGame {
  _TestMoovzDashGame()
    : super(gameBloc: _MockGameBloc(), audioController: _MockAudioController());

  @override
  Future<void> onLoad() async {}

  @override
  Images get images {
    final instance = _MockImages();

    final imageInstance = _MockImage();
    when(() => imageInstance.width).thenReturn(100);
    when(() => imageInstance.height).thenReturn(100);
    when(() => instance.load(any())).thenAnswer((_) async => imageInstance);

    return instance;
  }
}

TiledObject _objectOf(
  String type, {
  double x = 128,
  double y = 10,
  bool? low,
  bool? fly,
  String? path,
}) {
  return TiledObject(
    id: 1,
    x: x,
    y: y,
    properties: CustomProperties({
      'Type': StringProperty(name: 'Type', value: type),
      if (low != null) 'Low': BoolProperty(name: 'Low', value: low),
      if (fly != null) 'Fly': BoolProperty(name: 'Fly', value: fly),
      if (path != null) 'Path': StringProperty(name: 'Path', value: path),
    }),
  );
}

void main() {
  group('EnemyType.fromValue', () {
    test('parses new names', () {
      expect(EnemyType.fromValue('Cramp'), EnemyType.cramp);
      expect(EnemyType.fromValue('Soreness'), EnemyType.soreness);
      expect(EnemyType.fromValue('IcePack'), EnemyType.icePack);
      expect(
        EnemyType.fromValue('FatigueHourglass'),
        EnemyType.fatigueHourglass,
      );
      expect(EnemyType.fromValue('LazyCloud'), EnemyType.lazyCloud);
      expect(EnemyType.fromValue('Bandage'), EnemyType.bandage);
    });

    test('parses the low bar obstacle', () {
      expect(EnemyType.fromValue('LowBar'), EnemyType.lowBar);
    });

    test('parses legacy names', () {
      expect(EnemyType.fromValue('Beetle'), EnemyType.cramp);
      expect(EnemyType.fromValue('Ant'), EnemyType.soreness);
      expect(EnemyType.fromValue('Grasshopper'), EnemyType.icePack);
      expect(EnemyType.fromValue('Bee'), EnemyType.fatigueHourglass);
      expect(EnemyType.fromValue('Butterfly'), EnemyType.lazyCloud);
      expect(EnemyType.fromValue('Firefly'), EnemyType.bandage);
    });

    test('returns unknown for unmapped values', () {
      expect(EnemyType.fromValue(''), EnemyType.unknown);
      expect(EnemyType.fromValue('Dragon'), EnemyType.unknown);
    });

    test('every enemy type except unknown has a sprite sheet', () {
      for (final type in EnemyType.values.where(
        (t) => t != EnemyType.unknown,
      )) {
        expect(enemySpriteSheets[type], isNotNull);
      }
    });
  });

  group('Enemy low obstacles', () {
    const groundTop = 132.0;
    const standingTop = groundTop - 32;
    const slidingTop = groundTop - 16;
    const obstacleBaseAboveGround = 22.0;

    Rect playerBox({required bool sliding}) {
      final top = sliding ? slidingTop : standingTop;
      return Rect.fromLTWH(128, top, 32, groundTop - top);
    }

    testWithGame<_TestMoovzDashGame>(
      'LowBar has a 64x20 static hitbox at the object position',
      _TestMoovzDashGame.new,
      (game) async {
        final enemy = Enemy(
          tiledObject: _objectOf('LowBar', y: groundTop - 42),
        );
        await game.ensureAdd(enemy);

        expect(enemy.type, EnemyType.lowBar);
        expect(enemy.static, isTrue);
        expect(enemy.position, Vector2(128, groundTop - 42));
        expect(enemy.size, Vector2(64, 20));
        expect(enemy.children.whereType<FollowPathBehavior>(), isEmpty);
      },
    );

    testWithGame<_TestMoovzDashGame>(
      'LowBar sprite puts the bar rows over the hitbox and the chains above',
      _TestMoovzDashGame.new,
      (game) async {
        final enemy = Enemy(tiledObject: _objectOf('LowBar'));
        await game.ensureAdd(enemy);

        final sprite = enemy.children
            .whereType<SpriteAnimationComponent>()
            .single;

        expect(sprite.size, Vector2.all(64));
        expect(sprite.anchor, Anchor.topLeft);
        expect(sprite.position.y + 40, 0);
        expect(sprite.position.y + 60, enemy.size.y);
        expect(sprite.position.x, 0);
        expect(sprite.animation!.frames, hasLength(4));
        expect(sprite.animation!.loop, isTrue);
        expect(sprite.animation!.frames.first.stepTime, closeTo(.15, 1e-9));
      },
    );

    testWithGame<_TestMoovzDashGame>(
      'a Low mob is static, keeps a 32x32 hitbox and ignores its path',
      _TestMoovzDashGame.new,
      (game) async {
        final enemy = Enemy(
          tiledObject: _objectOf(
            'LazyCloud',
            y: groundTop - 54,
            low: true,
            path: 'I{1L, 1R}',
          ),
        );
        await game.ensureAdd(enemy);

        expect(enemy.static, isTrue);
        expect(enemy.position, Vector2(128, groundTop - 54));
        expect(enemy.size, Vector2.all(32));
        expect(enemy.children.whereType<FollowPathBehavior>(), isEmpty);
      },
    );

    testWithGame<_TestMoovzDashGame>(
      'a regular mob keeps moving along its path',
      _TestMoovzDashGame.new,
      (game) async {
        final enemy = Enemy(
          tiledObject: _objectOf('Cramp', low: false, path: 'I{1L, 1R}'),
        );
        await game.ensureAdd(enemy);

        expect(enemy.static, isFalse);
        expect(enemy.children.whereType<FollowPathBehavior>(), hasLength(1));
      },
    );

    testWithGame<_TestMoovzDashGame>(
      'a flying mob stays static and follows its path',
      _TestMoovzDashGame.new,
      (game) async {
        final enemy = Enemy(
          tiledObject: _objectOf('Bandage', fly: true, path: 'I{1L, 1R}'),
        );
        await game.ensureAdd(enemy);

        expect(enemy.static, isTrue);
        expect(enemy.children.whereType<FollowPathBehavior>(), hasLength(1));
      },
    );

    testWithGame<_TestMoovzDashGame>(
      'a standing player hits a LowBar but a sliding player passes under it',
      _TestMoovzDashGame.new,
      (game) async {
        final enemy = Enemy(
          tiledObject: _objectOf('LowBar', y: groundTop - 42),
        );
        await game.ensureAdd(enemy);
        final hitbox = Rect.fromLTWH(
          enemy.x,
          enemy.y,
          enemy.size.x,
          enemy.size.y,
        );

        expect(groundTop - hitbox.bottom, obstacleBaseAboveGround);
        expect(playerBox(sliding: false).overlaps(hitbox), isTrue);
        expect(playerBox(sliding: true).overlaps(hitbox), isFalse);
      },
    );

    testWithGame<_TestMoovzDashGame>(
      'a standing player hits a Low mob but a sliding player passes under it',
      _TestMoovzDashGame.new,
      (game) async {
        final enemy = Enemy(
          tiledObject: _objectOf('Bandage', y: groundTop - 54, low: true),
        );
        await game.ensureAdd(enemy);
        final hitbox = Rect.fromLTWH(
          enemy.x,
          enemy.y,
          enemy.size.x,
          enemy.size.y,
        );

        expect(groundTop - hitbox.bottom, obstacleBaseAboveGround);
        expect(playerBox(sliding: false).overlaps(hitbox), isTrue);
        expect(playerBox(sliding: true).overlaps(hitbox), isFalse);
      },
    );
  });
}
