import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _darkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
    ),
  );
}

void main() {
  group('GameElevatedButton', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _darkTheme(),
          home: Scaffold(
            body: GameElevatedButton(label: 'Play', onPressed: () {}),
          ),
        ),
      );

      expect(find.text('Play'), findsOneWidget);
    });

    testWidgets('label text is AppColors.onSurface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _darkTheme(),
          home: Scaffold(
            body: GameElevatedButton(label: 'Play', onPressed: () {}),
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Play'),
      );
      expect(paragraph.text.style?.color, AppColors.onSurface);
    });
  });
}
