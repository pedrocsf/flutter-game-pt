import 'package:app_ui/app_ui.dart';
import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moovz_dash/l10n/l10n.dart';
import 'package:moovz_dash/score/input_nickname/formatters/formatters.dart';
import 'package:moovz_dash/score/input_nickname/nickname_rules.dart';
import 'package:moovz_dash/score/score.dart';

class NicknameFormView extends StatefulWidget {
  const NicknameFormView({super.key});

  @override
  State<NicknameFormView> createState() => _NicknameFormViewState();
}

class _NicknameFormViewState extends State<NicknameFormView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<ScoreBloc, ScoreState>(
      listener: (context, state) {
        if (state.nicknameStatus == NicknameFormStatus.blacklisted) {
          _focusNode.requestFocus();
        }
      },
      builder: (context, state) {
        if (state.nicknameStatus == NicknameFormStatus.failure) {
          return const _ErrorBody();
        }
        return Column(
          children: [
            _NicknameField(
              controller: _controller,
              focusNode: _focusNode,
              isBlacklisted:
                  state.nicknameStatus == NicknameFormStatus.blacklisted,
              onChanged: (value) {
                context.read<ScoreBloc>().add(
                  ScoreNicknameUpdated(nickname: value),
                );
              },
              onSubmitted: () {
                context.read<ScoreBloc>().add(const ScoreNicknameSubmitted());
              },
            ),
            const SizedBox(height: 8),
            if (state.nicknameStatus == NicknameFormStatus.loading)
              const CircularProgressIndicator(color: AppColors.primary)
            else
              GameElevatedButton(
                label: l10n.enter,
                onPressed: () {
                  context.read<ScoreBloc>().add(const ScoreNicknameSubmitted());
                },
              ),
            const SizedBox(height: 8),
            if (state.nicknameStatus == NicknameFormStatus.blacklisted)
              _ErrorTextWidget(l10n.nicknameBlacklistedMessage)
            else if (_isInvalidNicknameMessageVisible(state))
              _ErrorTextWidget(l10n.nicknameErrorMessage),
          ],
        );
      },
    );
  }
}

bool _isInvalidNicknameMessageVisible(ScoreState state) {
  return state.nicknameStatus == NicknameFormStatus.invalid &&
      !nicknameRegex.hasMatch(state.nickname);
}

class _NicknameField extends StatelessWidget {
  const _NicknameField({
    required this.controller,
    required this.focusNode,
    required this.isBlacklisted,
    required this.onChanged,
    required this.onSubmitted,
  });

  static const _width = 280.0;
  static const _borderRadius = 16.0;
  static const _borderWidth = 2.0;
  static const _horizontalPadding = 16.0;

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isBlacklisted;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: _width,
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_borderRadius),
        color: AppColors.surface,
        border: Border.all(
          color: isBlacklisted
              ? AppColors.error
              : focusNode.hasPrimaryFocus
              ? AppColors.success
              : AppColors.border,
          width: _borderWidth,
        ),
      ),
      child: TextFormField(
        key: const Key('nickname_form_field'),
        controller: controller,
        autofocus: true,
        focusNode: focusNode,
        maxLength: nicknameMaxLength,
        inputFormatters: nicknameInputFormatters(),
        style: textTheme.headlineSmall,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          border: InputBorder.none,
          counterStyle: textTheme.bodySmall,
        ),
        onChanged: onChanged,
        onFieldSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        const SizedBox(height: 8),
        _ErrorTextWidget(l10n.scoreSubmissionErrorMessage),
        const SizedBox(height: 16),
        GameElevatedButton.icon(
          label: l10n.playAgain,
          icon: const Icon(Icons.refresh, size: 16),
          onPressed: () {
            context.flow<ScoreState>().complete();
          },
        ),
      ],
    );
  }
}

class _ErrorTextWidget extends StatelessWidget {
  const _ErrorTextWidget(this.text);

  static const _horizontalPadding = 24.0;

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(
            FontAwesomeIcons.circleExclamation,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text, textAlign: TextAlign.center, softWrap: true),
          ),
        ],
      ),
    );
  }
}
