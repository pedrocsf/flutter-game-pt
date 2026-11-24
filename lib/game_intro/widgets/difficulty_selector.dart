import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/l10n/l10n.dart';

class DifficultySelector extends StatelessWidget {
  const DifficultySelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final GameDifficulty selected;
  final ValueChanged<GameDifficulty> onChanged;

  String _label(AppLocalizations l10n, GameDifficulty difficulty) {
    switch (difficulty) {
      case GameDifficulty.easy:
        return l10n.difficultyEasy;
      case GameDifficulty.medium:
        return l10n.difficultyMedium;
      case GameDifficulty.hard:
        return l10n.difficultyHard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.difficultyLabel,
          style: textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final difficulty in GameDifficulty.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  key: ValueKey('difficulty_${difficulty.storageKey}'),
                  label: Text(_label(l10n, difficulty)),
                  selected: difficulty == selected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.black54,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => onChanged(difficulty),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
