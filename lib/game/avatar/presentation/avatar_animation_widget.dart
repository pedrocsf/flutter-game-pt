import 'package:flame/cache.dart';
import 'package:flame/extensions.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:moovz_dash/game/avatar/domain/avatar_animation.dart';
import 'package:moovz_dash/game/avatar/domain/avatar_appearance.dart';
import 'package:moovz_dash/game/avatar/domain/avatar_layer.dart';
import 'package:moovz_dash/game/avatar/presentation/avatar_layer_painter.dart';
import 'package:moovz_dash/game/moovz_dash_game.dart';

class AvatarAnimationWidget extends StatefulWidget {
  const AvatarAnimationWidget({
    required this.animation,
    required this.size,
    this.appearance = const AvatarAppearance.standard(),
    this.images,
    super.key,
  });

  static const layerFilterQuality = FilterQuality.medium;
  static const imagesPrefix = '';

  final AvatarAnimation animation;
  final AvatarAppearance appearance;
  final double size;
  final Images? images;

  static String assetPathOf(
    AvatarAppearance appearance,
    AvatarLayer layer,
    AvatarAnimation animation,
  ) {
    return '${MoovzDashGame.prefix}${appearance.assetPath(layer, animation)}';
  }

  @override
  State<AvatarAnimationWidget> createState() => _AvatarAnimationWidgetState();
}

typedef _LoadedLayer = ({SpriteAnimation animation, Paint paint});

class _AvatarAnimationWidgetState extends State<AvatarAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _frameClock;
  Images? _ownedImages;
  List<_LoadedLayer>? _layers;
  SpriteAnimationTicker? _frameTicker;
  Duration _lastElapsed = Duration.zero;
  int _loadGeneration = 0;

  Images get _images {
    return widget.images ??
        (_ownedImages ??= Images(prefix: AvatarAnimationWidget.imagesPrefix));
  }

  @override
  void initState() {
    super.initState();
    _frameClock = createTicker(_onFrameClockTick);
    _loadLayers();
  }

  @override
  void didUpdateWidget(AvatarAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sameAnimation = oldWidget.animation == widget.animation;
    final sameAppearance = oldWidget.appearance == widget.appearance;
    if (sameAnimation && sameAppearance) return;
    _loadLayers();
  }

  @override
  void dispose() {
    _frameClock.dispose();
    _ownedImages?.clearCache();
    super.dispose();
  }

  Future<void> _loadLayers() async {
    final generation = ++_loadGeneration;
    final animation = widget.animation;
    final appearance = widget.appearance;
    final images = await Future.wait(
      AvatarLayer.values.map(
        (layer) => _images.load(
          AvatarAnimationWidget.assetPathOf(appearance, layer, animation),
        ),
      ),
    );
    if (!mounted || generation != _loadGeneration) return;

    final data = _spriteData(animation);
    final layers = [
      for (final (index, layer) in AvatarLayer.values.indexed)
        (
          animation: SpriteAnimation.fromFrameData(images[index], data),
          paint: _layerPaint(appearance.styleOf(layer).tint),
        ),
    ];
    setState(() {
      _layers = layers;
      _frameTicker = layers.first.animation.createTicker();
    });
    _restartFrameClock();
  }

  static SpriteAnimationData _spriteData(AvatarAnimation animation) {
    return SpriteAnimationData.sequenced(
      amount: animation.frameCount,
      stepTime: avatarStepTime,
      textureSize: Vector2.all(avatarFrameSize),
      loop: animation.loop,
    );
  }

  static Paint _layerPaint(Color? tint) {
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = AvatarAnimationWidget.layerFilterQuality;
    if (tint == null) return paint;
    return paint..colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
  }

  void _restartFrameClock() {
    _lastElapsed = Duration.zero;
    _frameClock
      ..stop()
      ..start();
  }

  void _onFrameClockTick(Duration elapsed) {
    final frameTicker = _frameTicker;
    if (frameTicker == null) return;

    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    final previousIndex = frameTicker.currentIndex;
    frameTicker.update(delta.inMicroseconds / Duration.microsecondsPerSecond);

    if (frameTicker.done()) _frameClock.stop();
    if (frameTicker.currentIndex == previousIndex) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final layers = _layers;
    final frameTicker = _frameTicker;
    if (layers == null || frameTicker == null) {
      return SizedBox.square(dimension: widget.size);
    }

    final frameIndex = frameTicker.currentIndex;
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          for (final layer in layers)
            CustomPaint(
              painter: AvatarLayerPainter(
                sprite: layer.animation.frames[frameIndex].sprite,
                layerPaint: layer.paint,
              ),
            ),
        ],
      ),
    );
  }
}
