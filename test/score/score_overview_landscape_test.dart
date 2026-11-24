import 'package:bloc_test/bloc_test.dart';
import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moovz_dash/score/score.dart';
import 'package:moovz_dash/share/share.dart';

import '../helpers/helpers.dart';

class _MockScoreBloc extends MockBloc<ScoreEvent, ScoreState>
    implements ScoreBloc {}

class _MockShareController extends Mock implements ShareController {}

const _landscapeSizes = [Size(915, 412), Size(740, 360)];

void main() {
  group('ScoreOverviewPage landscape', () {
    for (final size in _landscapeSizes) {
      testWidgets('renders without overflow at $size', (tester) async {
        tester.setViewSize(size: size);
        final bloc = _MockScoreBloc();
        whenListen(
          bloc,
          const Stream<ScoreState>.empty(),
          initialState: const ScoreState(nickname: 'Pedro_Treino'),
        );
        when(() => bloc.score).thenReturn(123456);

        await tester.pumpApp(
          FlowBuilder<ScoreState>(
            controller: FakeFlowController<ScoreState>(const ScoreState()),
            onGeneratePages: (_, __) => [
              MaterialPage<void>(
                child: RepositoryProvider<ShareController>.value(
                  value: _MockShareController(),
                  child: BlocProvider<ScoreBloc>.value(
                    value: bloc,
                    child: const ScoreOverviewPage(),
                  ),
                ),
              ),
            ],
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Pedro_Treino'), findsOneWidget);
      });
    }
  });
}
