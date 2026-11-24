import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moovz_dash/constants/constants.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/game_intro/game_intro.dart';
import 'package:moovz_dash/gen/assets.gen.dart';
import 'package:moovz_dash/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class GameIntroPage extends StatefulWidget {
  const GameIntroPage({super.key});

  @override
  State<GameIntroPage> createState() => _GameIntroPageState();
}

class _GameIntroPageState extends State<GameIntroPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(Assets.images.gameBackground.provider(), context);
  }

  void _onDownload() {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    launchUrl(Uri.parse(isAndroid ? Urls.playStoreLink : Urls.appStoreLink));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: context.isSmall
                ? Assets.images.introBackgroundMobile.provider()
                : Assets.images.introBackgroundDesktop.provider(),
            fit: BoxFit.cover,
          ),
        ),
        child: isMobileWeb
            ? _MobileWebNotAvailableIntroPage(onDownload: _onDownload)
            : const _IntroPage(),
      ),
    );
  }

  bool get isMobileWeb =>
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

class _IntroPage extends StatefulWidget {
  const _IntroPage();

  @override
  State<_IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<_IntroPage> {
  static const double _logoWidth = 240;
  static const double _columnMaxWidth = 340;
  static const double _horizontalPadding = 32;
  static const double _verticalPadding = 8;
  static const double _sectionGap = 16;

  GameDifficulty _difficulty = GameDifficulty.medium;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
                vertical: _verticalPadding,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const MoovzLogo(width: _logoWidth),
                            const SizedBox(height: _sectionGap),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _columnMaxWidth,
                              ),
                              child: Text(
                                l10n.gameIntroPageHeadline,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DifficultySelector(
                              selected: _difficulty,
                              onChanged: (value) =>
                                  setState(() => _difficulty = value),
                            ),
                            const SizedBox(height: _sectionGap),
                            GameElevatedButton(
                              label: l10n.gameIntroPagePlayButtonText,
                              onPressed: () => Navigator.of(
                                context,
                              ).push(Game.route(difficulty: _difficulty)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _sectionGap),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      AudioButton(),
                      LeaderboardButton(),
                      BestiaryButton(),
                      InfoButton(),
                      HowToPlayButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileWebNotAvailableIntroPage extends StatelessWidget {
  const _MobileWebNotAvailableIntroPage({required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                const SizedBox(height: 16),
                const MoovzLogo(width: 282),
                const SizedBox(height: 16),
                Text(
                  l10n.downloadAppMessage,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 24),
                GameElevatedButton.icon(
                  label: l10n.downloadAppLabel,
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: onDownload,
                ),
                const SizedBox(height: 16),
                const BottomBar(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
