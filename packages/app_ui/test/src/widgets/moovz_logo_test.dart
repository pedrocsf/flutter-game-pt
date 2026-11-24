import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoovzLogo', () {
    testWidgets('renders an SvgPicture', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MoovzLogo()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('applies the given width and height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MoovzLogo(width: 120, height: 40)),
        ),
      );
      await tester.pumpAndSettle();

      final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(picture.width, 120);
      expect(picture.height, 40);
    });
  });
}
