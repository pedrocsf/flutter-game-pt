import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart' hide PointerMoveEvent;
import 'package:flame/sprite.dart';
import 'package:flame/text.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leap/leap.dart';
import 'package:moovz_dash/audio/audio.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/score/score.dart';

bool _tsxPackingFilter(Tileset tileset) {
  return !(tileset.source ?? '').startsWith('anim');
}

Paint _layerPaintFactory(double opacity) {
  return Paint()
    ..color = Color.fromRGBO(255, 255, 255, opacity)
    ..isAntiAlias = false;
}

class MoovzDashGame extends LeapGame with HasKeyboardHandlerComponents {
  MoovzDashGame({
    required this.gameBloc,
    required this.audioController,
    this.customBundle,
    this.inMapTester = false,
    this.avatarAppearance = const AvatarAppearance.standard(),
    this.difficulty = GameDifficulty.medium,
  }) : super(
         tileSize: 64,
         configuration: const LeapConfiguration(
           tiled: TiledOptions(
             atlasMaxX: 4048,
             atlasMaxY: 4048,
             tsxPackingFilter: _tsxPackingFilter,
             layerPaintFactory: _layerPaintFactory,
             atlasPackingSpacingX: 4,
             atlasPackingSpacingY: 4,
           ),
         ),
       );

  static const _cameraViewportMinWidth = 1024.0;
  static const _cameraViewportMaxWidth = 1400.0;
  static const _cameraViewportHeight = 592.0;
  static const _spawnerProximityFactor = 1.5;
  final Vector2 _cameraViewport = Vector2(
    _cameraViewportMinWidth,
    _cameraViewportHeight,
  );
  bool _cameraReady = false;
  static const int sectionClearPointsPerLevel = 1000;
  static const prefix = 'assets/map/';
  static const sectionCount = 3;
  static const _seedBound = 1 << 31;
  static const _fixedSections = [
    'flutter_runnergame_map_A.tmx',
    'flutter_runnergame_map_B.tmx',
    'flutter_runnergame_map_C.tmx',
  ];
  static const _sectionZeroSkyTop = Color(0xFF1A1210);
  static const _sectionZeroSkyBottom = Color(0xFF4A2616);
  static const _sectionOneSkyTop = Color(0xFF1F1512);
  static const _sectionOneSkyBottom = Color(0xFF5A2A14);
  static const _sectionTwoSkyTop = Color(0xFF140E14);
  static const _sectionTwoSkyBottom = Color(0xFF3A1F2E);
  static const _sectionsBackgroundColor = [
    (_sectionZeroSkyTop, _sectionZeroSkyBottom),
    (_sectionOneSkyTop, _sectionOneSkyBottom),
    (_sectionTwoSkyTop, _sectionTwoSkyBottom),
  ];

  final GameBloc gameBloc;
  final AssetBundle? customBundle;
  final AudioController audioController;
  final AvatarAppearance avatarAppearance;
  final GameDifficulty difficulty;
  final List<VoidCallback> _jumpListeners = [];
  final List<VoidCallback> _slideListeners = [];
  late final PointerGestureTracker _gestureTracker = PointerGestureTracker(
    onJump: triggerJump,
    onSlide: triggerSlide,
  );
  final Random _seedRandom = Random();

  int matchSeed = 0;
  ProceduralMapGenerator? _generator;
  ProceduralMapAssetBundle? _proceduralBundle;

  late final SpriteSheet itemsSpritesheet;
  final bool inMapTester;

  GameState get state => gameBloc.state;

  Player? get player => world.firstChild<Player>();

  List<Tileset> get tilesets => leapMap.tiledMap.tileMap.map.tilesets;

  Tileset get itemsTileset {
    return tilesets.firstWhere((tileset) => tileset.name == 'tile_items_v2');
  }

  Tileset get enemiesTileset {
    return tilesets.firstWhere((tileset) => tileset.name == 'tile_enemies_v2');
  }

  void addJumpListener(VoidCallback listener) {
    _jumpListeners.add(listener);
  }

  void removeJumpListener(VoidCallback listener) {
    _jumpListeners.remove(listener);
  }

  void addSlideListener(VoidCallback listener) {
    _slideListeners.add(listener);
  }

  void removeSlideListener(VoidCallback listener) {
    _slideListeners.remove(listener);
  }

  void addInputListener(VoidCallback listener) => addJumpListener(listener);

  void removeInputListener(VoidCallback listener) =>
      removeJumpListener(listener);

  void triggerJump() {
    for (final listener in List.of(_jumpListeners)) {
      listener();
    }
    overlays.remove('tapToJump');
  }

  void triggerSlide() {
    for (final listener in List.of(_slideListeners)) {
      listener();
    }
  }

  void handlePointerDown(PointerDownEvent event) {
    _gestureTracker.pointerDown(event.pointer, event.localPosition);
  }

  void handlePointerMove(PointerMoveEvent event) {
    _gestureTracker.pointerMove(event.pointer, event.localPosition);
  }

  void handlePointerUp(PointerUpEvent event) {
    _gestureTracker.pointerUp(event.pointer, event.localPosition);
  }

  void handlePointerCancel(PointerCancelEvent event) {
    _gestureTracker.pointerCancel(event.pointer);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (inMapTester) {
      _addMapTesterFeatures();
    }

    if (kIsWeb && audioController.isMusicEnabled) {
      audioController.startMusic();
    }

    _updateCameraViewportWidth(canvasSize);
    camera = CameraComponent.withFixedResolution(
      width: _cameraViewport.x,
      height: _cameraViewport.y,
    )..world = world;
    _cameraReady = true;

    images = Images(prefix: prefix, bundle: customBundle);

    itemsSpritesheet = SpriteSheet(
      image: await images.load('objects/tile_items_v2.png'),
      srcSize: Vector2.all(tileSize),
    );

    if (!inMapTester) await _prepareGenerator();
    startNewMatch();
    await _loadSection(0);
    _setSectionBackground();

    final player = Player(
      levelSize: leapMap.tiledMap.size.clone(),
      cameraViewport: _cameraViewport,
    );
    unawaited(world.addAll([player]));

    await _addSpawners();
    _addTreeHouseFrontLayer();
    _addTreeHouseSign();

    add(buildKeyboardListener());
  }

  @visibleForTesting
  KeyboardListenerComponent buildKeyboardListener() {
    bool handleKey(VoidCallback action) {
      action();
      return false;
    }

    return KeyboardListenerComponent(
      keyDown: {
        LogicalKeyboardKey.space: (_) => handleKey(triggerJump),
        LogicalKeyboardKey.arrowUp: (_) => handleKey(triggerJump),
        LogicalKeyboardKey.arrowDown: (_) => handleKey(triggerSlide),
        LogicalKeyboardKey.keyS: (_) => handleKey(triggerSlide),
      },
      keyUp: {
        LogicalKeyboardKey.space: (_) => false,
        LogicalKeyboardKey.arrowUp: (_) => false,
        LogicalKeyboardKey.arrowDown: (_) => false,
        LogicalKeyboardKey.keyS: (_) => false,
      },
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_cameraReady) return;
    if (_updateCameraViewportWidth(size)) {
      camera.viewport = FixedResolutionViewport(
        resolution: _cameraViewport.clone(),
      );
    }
  }

  bool _updateCameraViewportWidth(Vector2 canvas) {
    if (canvas.x <= 0 || canvas.y <= 0) return false;
    final width = (_cameraViewportHeight * canvas.x / canvas.y).clamp(
      _cameraViewportMinWidth,
      _cameraViewportMaxWidth,
    );
    if (width == _cameraViewport.x) return false;
    _cameraViewport.x = width;
    return true;
  }

  Future<void> _prepareGenerator() async {
    final baseBundle = customBundle ?? rootBundle;
    final library = await ChunkLibrary.load(baseBundle);
    _generator = ProceduralMapGenerator(library: library);
    _proceduralBundle = ProceduralMapAssetBundle(baseBundle: baseBundle);
  }

  void startNewMatch() {
    matchSeed = _seedRandom.nextInt(_seedBound);
  }

  Future<void> _loadSection(int index) {
    final generator = _generator;
    final proceduralBundle = _proceduralBundle;
    if (inMapTester || generator == null || proceduralBundle == null) {
      return loadWorldAndMap(
        images: images,
        prefix: prefix,
        bundle: customBundle,
        tiledMapPath: _fixedSections[index],
      );
    }
    final fileName = 'procedural_section_$index.tmx';
    proceduralBundle.putMap(
      '$prefix$fileName',
      generator.generateSection(
        seed: matchSeed,
        sectionIndex: index,
        sectionCount: sectionCount,
        difficulty: difficulty,
      ),
    );
    return loadWorldAndMap(
      images: images,
      prefix: prefix,
      bundle: proceduralBundle,
      tiledMapPath: fileName,
    );
  }

  void _addTreeHouseSign() {
    world.add(TreeSign(position: Vector2(448, 1862)));
  }

  void _addTreeHouseFrontLayer() {
    final layer = leapMap.tiledMap.tileMap.renderableLayers.last;
    world.add(TreeHouseFront(renderFront: layer.render));
  }

  void _setSectionBackground() {
    final colors = _sectionsBackgroundColor[state.currentSection];
    camera.backdrop = RectangleComponent(
      size: size.clone(),
      paint: Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(size.x, size.y), [
          colors.$1,
          colors.$2,
        ]),
    );
  }

  void gameOver() {
    gameBloc.add(const GameOver());
    world.firstChild<Player>()?.removeFromParent();

    _resetEntities();

    Future<void>.delayed(const Duration(seconds: 1), () async {
      startNewMatch();
      await _loadSection(0);
      if (isLastSection || isFirstSection) {
        _addTreeHouseFrontLayer();
      }

      if (isFirstSection) {
        _addTreeHouseSign();
      }
      final newPlayer = Player(
        levelSize: leapMap.tiledMap.size.clone(),
        cameraViewport: _cameraViewport,
      );
      await world.add(newPlayer);

      await newPlayer.mounted;
      await _addSpawners();
      overlays.add('tapToJump');
    });

    if (buildContext != null) {
      final score = gameBloc.state.score;
      Navigator.of(
        buildContext!,
      ).push(ScorePage.route(score: score, difficulty: difficulty));
    }
  }

  void _resetEntities() {
    children.whereType<ObjectGroupProximityBuilder<Player>>().forEach(
      (spawner) => spawner.removeFromParent(),
    );
    world.firstChild<TreeHouseFront>()?.removeFromParent();
    world.firstChild<TreeSign>()?.removeFromParent();

    leapMap.children.whereType<Enemy>().forEach(
      (enemy) => enemy.removeFromParent(),
    );
    leapMap.children.whereType<Item>().forEach(
      (enemy) => enemy.removeFromParent(),
    );
  }

  Future<void> _addSpawners() async {
    await addAll([
      ObjectGroupProximityBuilder<Player>(
        proximity: _cameraViewport.x * _spawnerProximityFactor,
        tileLayerName: 'items',
        tileset: itemsTileset,
        componentBuilder: Item.new,
      ),
      ObjectGroupProximityBuilder<Player>(
        proximity: _cameraViewport.x * _spawnerProximityFactor,
        tileLayerName: 'enemies',
        tileset: enemiesTileset,
        componentBuilder: Enemy.new,
      ),
    ]);
  }

  Future<void> _loadNewSection() async {
    final nextSectionIndex = state.currentSection + 1 < sectionCount
        ? state.currentSection + 1
        : 0;

    _resetEntities();

    await _loadSection(nextSectionIndex);

    if (isFirstSection) {
      _addTreeHouseSign();
    }

    if (isLastSection || isFirstSection) {
      _addTreeHouseFrontLayer();
    }

    await _addSpawners();
  }

  @override
  void onMapUnload(LeapMap map) {
    player?.velocity.setZero();
  }

  @override
  void onMapLoaded(LeapMap map) {
    player?.slideBehavior.endSlide(force: true);
    player?.velocity.setZero();
    player?.loadSpawnPoint();
    player?.loadRespawnPoints();
    player?.cameraAnchor.snapToPlayer(levelSize: map.tiledMap.size.clone());
    player?.walking = true;
    player?.spritePaintColor(Colors.white);
    player?.isPlayerTeleporting = false;

    _setSectionBackground();
  }

  void sectionCleared() {
    if (isLastSection) {
      player?.spritePaintColor(Colors.transparent);
      player?.walking = false;
    }

    _loadNewSection();

    gameBloc
      ..add(
        GameScoreIncreased(by: sectionClearPointsPerLevel * state.currentLevel),
      )
      ..add(GameSectionCompleted(sectionCount: sectionCount));
  }

  bool get isLastSection => state.currentSection == sectionCount - 1;
  bool get isFirstSection => state.currentSection == 0;

  void addCameraDebugger() {
    if (descendants().whereType<CameraDebugger>().isEmpty) {
      final player = world.firstChild<Player>()!;

      final cameraDebugger = CameraDebugger(position: player.position.clone());
      world.add(cameraDebugger);

      final anchor = PlayerCameraAnchor(
        levelSize: leapMap.tiledMap.size.clone(),
        cameraViewport: _cameraViewport,
      );
      cameraDebugger.add(anchor);
      camera.follow(anchor);

      final proximityBuilders = descendants()
          .whereType<ObjectGroupProximityBuilder<Player>>();
      for (final proximityBuilder in proximityBuilders) {
        proximityBuilder.currentReference = cameraDebugger;
      }

      player.removeFromParent();
    }
  }

  void toggleInvincibility() {
    player?.isPlayerInvincible = !(player?.isPlayerInvincible ?? false);
  }

  void teleportPlayerToEnd() {
    player?.x = leapMap.tiledMap.size.x - (player?.size.x ?? 0) * 10 * 4;
    if (state.currentSection == 2) {
      player?.y = (player?.y ?? 0) - (tileSize * 4);
    }
  }

  void showHitBoxes() {
    void show() {
      descendants()
          .whereType<PhysicalEntity>()
          .where(
            (element) =>
                element is Player || element is Item || element is Enemy,
          )
          .forEach((entity) => entity.debugMode = true);
    }

    show();
    add(TimerComponent(period: 1, repeat: true, onTick: show));
  }

  void _addMapTesterFeatures() {
    add(FpsComponent());
    add(
      FpsTextComponent(
        position: Vector2(0, 0),
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
      ),
    );
  }
}
