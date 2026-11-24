import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moovz_dash/bestiary/bestiary.dart';
import 'package:moovz_dash/game_intro/game_intro.dart';
import 'package:moovz_dash/leaderboard/leaderboard.dart';
import 'package:moovz_dash/settings/settings_controller.dart';

class AudioButton extends StatelessWidget {
  const AudioButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = context.watch<SettingsController>();
    return ValueListenableBuilder<bool>(
      valueListenable: settingsController.muted,
      builder: (context, muted, child) => GameIconButton(
        icon: muted ? Icons.volume_off : Icons.volume_up,
        onPressed: context.read<SettingsController>().toggleMuted,
      ),
    );
  }
}

class LeaderboardButton extends StatelessWidget {
  const LeaderboardButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GameIconButton(
      icon: FontAwesomeIcons.trophy.data,
      size: 18,
      alignment: const Alignment(-0.3, 0),
      onPressed: () => Navigator.of(context).push(LeaderboardPage.route()),
    );
  }
}

class BestiaryButton extends StatelessWidget {
  const BestiaryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GameIconButton(
      icon: Icons.pest_control,
      onPressed: () => Navigator.of(context).push(BestiaryPage.route()),
    );
  }
}

class InfoButton extends StatelessWidget {
  const InfoButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GameIconButton(
      icon: Icons.info,
      onPressed: () => Navigator.of(context).push(GameInfoDialog.route()),
    );
  }
}

class HowToPlayButton extends StatelessWidget {
  const HowToPlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GameIconButton(
      icon: Icons.help,
      onPressed: () =>
          Navigator.of(context).push(GameInstructionsOverlay.route()),
    );
  }
}
