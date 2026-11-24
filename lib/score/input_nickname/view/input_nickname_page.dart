import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/gen/assets.gen.dart';
import 'package:moovz_dash/l10n/l10n.dart';
import 'package:moovz_dash/score/score.dart';
import 'package:moovz_dash/utils/utils.dart';

const double _gap = 12;
const double _iconSize = 52;

class InputNicknamePage extends StatelessWidget {
  const InputNicknamePage({super.key});

  static Page<void> page() {
    return const MaterialPage<void>(child: InputNicknamePage());
  }

  @override
  Widget build(BuildContext context) {
    return PageWithBackground(
      background: const GameBackground(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Assets.images.gameOverBg.provider(),
            fit: BoxFit.cover,
            alignment: isDesktop
                ? const Alignment(0, .7)
                : Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: _gap),
                      SizedBox(
                        height: _iconSize,
                        width: _iconSize,
                        child: TraslucentBackground(
                          gradient: const [
                            AppColors.onSurfaceMuted,
                            AppColors.surface,
                          ],
                          border: Border.all(color: Colors.white),
                          child: const Align(
                            alignment: Alignment(-0.06, 0),
                            child: FaIcon(
                              FontAwesomeIcons.trophy,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: _gap),
                      Text(
                        context.l10n.inputNicknamePageHeadline,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: _gap),
                      const NicknameFormView(),
                      const SizedBox(height: _gap),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
