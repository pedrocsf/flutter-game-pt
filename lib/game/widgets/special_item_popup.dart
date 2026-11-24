import 'package:app_ui/app_ui.dart';
import 'package:flame/cache.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moovz_dash/game/bloc/game_bloc.dart';
import 'package:moovz_dash/game/entities/item_animation_sheet.dart';
import 'package:moovz_dash/game/entities/item_type.dart';
import 'package:moovz_dash/game/moovz_dash_game.dart';
import 'package:moovz_dash/l10n/l10n.dart';

class SpecialItemPopup extends StatefulWidget {
  const SpecialItemPopup({super.key});

  static const enterDuration = Duration(milliseconds: 200);
  static const holdDuration = Duration(milliseconds: 1200);
  static const exitDuration = Duration(milliseconds: 400);
  static const initialScale = .6;
  static const iconSize = 56.0;

  static Duration get totalDuration =>
      enterDuration + holdDuration + exitDuration;

  @override
  State<SpecialItemPopup> createState() => _SpecialItemPopupState();
}

class _SpecialItemPopupState extends State<SpecialItemPopup>
    with SingleTickerProviderStateMixin {
  static final Images _images = Images(prefix: MoovzDashGame.prefix);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SpecialItemPopup.totalDuration,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: SpecialItemPopup.initialScale,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: _enterInterval));

  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0, end: 1),
      weight: SpecialItemPopup.enterDuration.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: ConstantTween(1),
      weight: SpecialItemPopup.holdDuration.inMilliseconds.toDouble(),
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1, end: 0),
      weight: SpecialItemPopup.exitDuration.inMilliseconds.toDouble(),
    ),
  ]).animate(_controller);

  static final Interval _enterInterval = Interval(
    0,
    SpecialItemPopup.enterDuration.inMilliseconds /
        SpecialItemPopup.totalDuration.inMilliseconds,
    curve: Curves.easeOutBack,
  );

  ItemType? _itemType;
  int _sequence = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _show(GameState state) {
    setState(() {
      _itemType = state.lastSpecialItem;
      _sequence = state.specialItemSequence;
    });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameState>(
      listenWhen: (previous, current) =>
          previous.specialItemSequence != current.specialItemSequence &&
          current.lastSpecialItem != null,
      listener: (context, state) => _show(state),
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final itemType = _itemType;
            if (itemType == null || !_controller.isAnimating) {
              return const SizedBox.shrink();
            }
            return Opacity(
              opacity: _opacity.value.clamp(0, 1),
              child: Transform.scale(scale: _scale.value, child: child),
            );
          },
          child: _itemType == null
              ? null
              : _PopupCard(
                  key: ValueKey(_sequence),
                  itemType: _itemType!,
                  images: _images,
                ),
        ),
      ),
    );
  }
}

class _PopupCard extends StatelessWidget {
  const _PopupCard({required this.itemType, required this.images, super.key});

  final ItemType itemType;
  final Images images;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final sheet = itemAnimationSheets[itemType];

    return TraslucentBackground(
      shape: BoxShape.rectangle,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white),
      gradient: const [AppColors.surface, AppColors.background],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sheet != null)
              SpriteAnimationWidget.asset(
                path: sheet.file,
                data: sheet.toAnimationData(),
                images: images,
                size: const Size.square(SpecialItemPopup.iconSize),
                loadingBuilder: (_) => _iconPlaceholder,
                errorBuilder: (_) => _iconPlaceholder,
              ),
            const SizedBox(width: 14),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemType.popupName(l10n),
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  itemType.popupEffect(l10n),
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _iconPlaceholder = SizedBox.square(
    dimension: SpecialItemPopup.iconSize,
  );
}

extension on ItemType {
  String popupName(AppLocalizations l10n) {
    return switch (this) {
      ItemType.medal => l10n.specialItemMedalName,
      ItemType.zoneFive => l10n.specialItemZoneFiveName,
      ItemType.extraLife => l10n.specialItemExtraLifeName,
      ItemType.energy => '',
    };
  }

  String popupEffect(AppLocalizations l10n) {
    return switch (this) {
      ItemType.medal => l10n.specialItemMedalEffect(ItemType.medalPoints),
      ItemType.zoneFive => l10n.specialItemZoneFiveEffect,
      ItemType.extraLife => l10n.specialItemExtraLifeEffect,
      ItemType.energy => '',
    };
  }
}
