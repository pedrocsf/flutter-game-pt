import 'package:bloc_test/bloc_test.dart';
import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/game_intro/game_intro.dart';
import 'package:moovz_dash/score/game_over/game_over.dart';
import 'package:moovz_dash/score/score.dart';

import '../helpers/helpers.dart';

class _MockScoreBloc extends MockBloc<ScoreEvent, ScoreState>
    implements ScoreBloc {}

const _landscapeSizes = [Size(915, 412), Size(740, 360)];

Widget _scorePage(Widget page) {
  final bloc = _MockScoreBloc();
  whenListen(
    bloc,
    const Stream<ScoreState>.empty(),
    initialState: const ScoreState(),
  );
  when(() => bloc.score).thenReturn(1234);
  return FlowBuilder<ScoreState>(
    controller: FakeFlowController<ScoreState>(const ScoreState()),
    onGeneratePages: (_, __) => [
      MaterialPage<void>(
        child: BlocProvider<ScoreBloc>.value(value: bloc, child: page),
      ),
    ],
  );
}

void main() {
  for (final size in _landscapeSizes) {
    group('landscape $size', () {
      testWidgets('GameOverPage has no overflow', (tester) async {
        tester.setViewSize(size: size);
        await tester.pumpApp(_scorePage(const GameOverPage()));
        expect(tester.takeException(), isNull);
      });

      testWidgets('InputNicknamePage has no overflow', (tester) async {
        tester.setViewSize(size: size);
        await tester.pumpApp(_scorePage(const InputNicknamePage()));
        expect(tester.takeException(), isNull);
      });

      testWidgets('GameInstructionsOverlay has no overflow', (tester) async {
        tester.setViewSize(size: size);
        await tester.pumpApp(const GameInstructionsOverlay());
        expect(tester.takeException(), isNull);
      });

      testWidgets('GameInfoDialog has no overflow', (tester) async {
        tester.setViewSize(size: size);
        await tester.pumpApp(const GameInfoDialog());
        expect(tester.takeException(), isNull);
      });
    });
  }
}
