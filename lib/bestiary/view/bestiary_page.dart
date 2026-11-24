import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/l10n/l10n.dart';

const _spriteSize = 64.0;
const _cardWidth = 150.0;
const _gap = 12.0;
const _pagePadding = 16.0;
const _assetPrefix = 'assets/map/';
const _lowBarFrameSize = 64.0;
const _sectionGap = 20.0;
const _energyAsset = 'assets/map/objects/tile_items_v2.png';

class _ItemEntry {
  const _ItemEntry({
    required this.asset,
    required this.name,
    required this.effect,
    this.alignment = Alignment.topLeft,
  });

  final String asset;
  final String name;
  final String effect;
  final Alignment alignment;
}

String enemyDisplayName(AppLocalizations l10n, EnemyType type) {
  return switch (type) {
    EnemyType.cramp => l10n.enemyNameCramp,
    EnemyType.soreness => l10n.enemyNameSoreness,
    EnemyType.icePack => l10n.enemyNameIcePack,
    EnemyType.fatigueHourglass => l10n.enemyNameFatigueHourglass,
    EnemyType.lazyCloud => l10n.enemyNameLazyCloud,
    EnemyType.bandage => l10n.enemyNameBandage,
    EnemyType.lowBar => l10n.enemyNameLowBar,
    EnemyType.unknown => '',
  };
}

class BestiaryPage extends StatelessWidget {
  const BestiaryPage({super.key});

  static PageRoute<void> route() {
    return PageRouteBuilder(pageBuilder: (_, __, ___) => const BestiaryPage());
  }

  List<_ItemEntry> _items(AppLocalizations l10n) {
    String sheet(ItemType type) =>
        '$_assetPrefix${itemAnimationSheets[type]!.file}';
    return [
      _ItemEntry(
        asset: _energyAsset,
        name: l10n.itemNameEnergy,
        effect: l10n.specialItemMedalEffect(ItemType.energyPoints),
        alignment: Alignment.topRight,
      ),
      _ItemEntry(
        asset: sheet(ItemType.medal),
        name: l10n.specialItemMedalName,
        effect: l10n.specialItemMedalEffect(ItemType.medalPoints),
      ),
      _ItemEntry(
        asset: sheet(ItemType.zoneFive),
        name: l10n.specialItemZoneFiveName,
        effect: l10n.specialItemZoneFiveEffect,
      ),
      _ItemEntry(
        asset: sheet(ItemType.extraLife),
        name: l10n.specialItemExtraLifeName,
        effect: l10n.specialItemExtraLifeEffect,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return PageWithBackground(
      background: const GameBackground(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: _gap),
                  Text(l10n.bestiaryTitle, style: textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: _gap),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        l10n.bestiaryEnemiesHeading,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: _gap),
                      Wrap(
                        spacing: _gap,
                        runSpacing: _gap,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final entry in enemySpriteSheets.entries)
                            _EntryCard(
                              asset: '$_assetPrefix${entry.value.file}',
                              name: enemyDisplayName(l10n, entry.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: _sectionGap),
                      Text(
                        l10n.bestiaryItemsHeading,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: _gap),
                      Wrap(
                        spacing: _gap,
                        runSpacing: _gap,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final item in _items(l10n))
                            _EntryCard(
                              asset: item.asset,
                              name: item.name,
                              effect: item.effect,
                              alignment: item.alignment,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.asset,
    required this.name,
    this.effect,
    this.alignment = Alignment.topLeft,
  });

  final String asset;
  final String name;
  final String? effect;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: _cardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(_gap),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_gap),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _spriteSize,
                height: _spriteSize,
                child: ClipRect(
                  child: Image.asset(
                    asset,
                    width: _spriteSize,
                    height: _spriteSize,
                    fit: BoxFit.none,
                    alignment: alignment,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: _lowBarFrameSize),
                  ),
                ),
              ),
              const SizedBox(height: _gap),
              Text(
                name,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall,
              ),
              if (effect != null) ...[
                const SizedBox(height: 4),
                Text(
                  effect!,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
