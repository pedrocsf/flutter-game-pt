import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:moovz_dash/l10n/l10n.dart';

class TapToJumpOverlay extends StatelessWidget {
  const TapToJumpOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
            color: AppColors.surfaceDialog,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.tapToStart,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
