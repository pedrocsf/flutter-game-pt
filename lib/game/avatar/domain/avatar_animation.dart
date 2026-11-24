const double avatarFrameSize = 128;
const double avatarSoleBottom = 126;
const double avatarStepTime = 0.042;

enum AvatarAnimation {
  idle('idle', 18, loop: true),
  run('run', 16, loop: true),
  jump('jump', 16, loop: false),
  doubleJump('doubleJump', 16, loop: false),
  slide('slide', 16, loop: true),
  deathPit('deathPit', 24, loop: false),
  deathFaint('deathFaint', 24, loop: false);

  const AvatarAnimation(this.fileName, this.frameCount, {required this.loop});

  final String fileName;
  final int frameCount;
  final bool loop;
}
