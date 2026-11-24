import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/l10n/l10n.dart';
import 'package:moovz_dash/score/score.dart';

import '../../../helpers/helpers.dart';

class _MockScoreBloc extends MockBloc<ScoreEvent, ScoreState>
    implements ScoreBloc {}

const _validNickname = 'Pedro_Treino';
const _shortNickname = 'ab';
const _blacklistedNickname = 'fuk';
const _narrowViewWidth = 360.0;
const _viewHeight = 800.0;

Widget _buildSubject(ScoreState state, {Locale locale = const Locale('en')}) {
  final bloc = _MockScoreBloc();
  whenListen(bloc, const Stream<ScoreState>.empty(), initialState: state);

  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<ScoreBloc>.value(
        value: bloc,
        child: const NicknameFormView(),
      ),
    ),
  );
}

AppLocalizations _l10n(Locale locale) => lookupAppLocalizations(locale);

void main() {
  group('NicknameFormView', () {
    testWidgets('shows no error message before any submission', (tester) async {
      await tester.pumpWidget(_buildSubject(const ScoreState()));

      final l10n = _l10n(const Locale('en'));
      expect(find.text(l10n.nicknameErrorMessage), findsNothing);
      expect(find.text(l10n.nicknameBlacklistedMessage), findsNothing);
    });

    testWidgets(
      'hides the invalid message when the current nickname is valid',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            const ScoreState(
              nickname: _validNickname,
              nicknameStatus: NicknameFormStatus.invalid,
            ),
          ),
        );

        final l10n = _l10n(const Locale('en'));
        expect(find.text(l10n.nicknameErrorMessage), findsNothing);
      },
    );

    testWidgets('shows the invalid message for a nickname that is too short', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          const ScoreState(
            nickname: _shortNickname,
            nicknameStatus: NicknameFormStatus.invalid,
          ),
        ),
      );

      final l10n = _l10n(const Locale('en'));
      expect(find.text(l10n.nicknameErrorMessage), findsOneWidget);
      expect(find.text(l10n.nicknameBlacklistedMessage), findsNothing);
    });

    testWidgets('shows the blacklisted message for a blocked nickname', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          const ScoreState(
            nickname: _blacklistedNickname,
            nicknameStatus: NicknameFormStatus.blacklisted,
          ),
        ),
      );

      final l10n = _l10n(const Locale('en'));
      expect(find.text(l10n.nicknameBlacklistedMessage), findsOneWidget);
      expect(find.text(l10n.nicknameErrorMessage), findsNothing);
    });

    for (final locale in const [Locale('en'), Locale('pt')]) {
      testWidgets('does not overflow at 360 dp in ${locale.languageCode}', (
        tester,
      ) async {
        tester.setViewSize(size: const Size(_narrowViewWidth, _viewHeight));

        await tester.pumpWidget(
          _buildSubject(
            const ScoreState(
              nickname: _shortNickname,
              nicknameStatus: NicknameFormStatus.invalid,
            ),
            locale: locale,
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text(_l10n(locale).nicknameErrorMessage), findsOneWidget);
      });
    }
  });
}
