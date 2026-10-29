import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';

void main() {
  test('light app bars keep Android clock and battery dark and readable', () {
    expect(
      AppTheme
          .lightTheme
          .appBarTheme
          .systemOverlayStyle
          ?.statusBarIconBrightness,
      Brightness.dark,
    );
  });
  test('dark app bars keep Android clock and battery light and readable', () {
    expect(
      AppTheme
          .darkTheme
          .appBarTheme
          .systemOverlayStyle
          ?.statusBarIconBrightness,
      Brightness.light,
    );
  });
}
