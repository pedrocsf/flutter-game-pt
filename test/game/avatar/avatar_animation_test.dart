import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/avatar/avatar.dart';

void main() {
  group('AvatarAnimation', () {
    test('has the frame count of each animation', () {
      expect(AvatarAnimation.idle.frameCount, equals(18));
      expect(AvatarAnimation.run.frameCount, equals(16));
      expect(AvatarAnimation.jump.frameCount, equals(16));
      expect(AvatarAnimation.doubleJump.frameCount, equals(16));
      expect(AvatarAnimation.deathPit.frameCount, equals(24));
      expect(AvatarAnimation.deathFaint.frameCount, equals(24));
    });

    test('slide has 16 looping frames', () {
      expect(AvatarAnimation.slide.fileName, equals('slide'));
      expect(AvatarAnimation.slide.frameCount, equals(16));
      expect(AvatarAnimation.slide.loop, isTrue);
    });

    test('loops only idle, run and slide', () {
      final looping = AvatarAnimation.values.where((animation) {
        return animation.loop;
      });

      expect(
        looping,
        equals([
          AvatarAnimation.idle,
          AvatarAnimation.run,
          AvatarAnimation.slide,
        ]),
      );
    });

    test('uses the animation name as file name', () {
      expect(AvatarAnimation.doubleJump.fileName, equals('doubleJump'));
      expect(AvatarAnimation.deathPit.fileName, equals('deathPit'));
    });
  });

  group('avatar sprite constants', () {
    test('frame size is 128 pixels', () {
      expect(avatarFrameSize, equals(128));
    });

    test('step time is 0.042 seconds', () {
      expect(avatarStepTime, equals(0.042));
    });
  });
}
