import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('primary is the Moovz brand orange', () {
      expect(AppColors.primary, const Color(0xFFF85F00));
    });

    test('onSurface is white', () {
      expect(AppColors.onSurface, const Color(0xFFFFFFFF));
    });
  });
}
