import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/data/cooking_tips.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/screens/home/cooking_tips_screen.dart';
import '../../fixtures/cooking_tips_pl_before.dart';

Future<void> openTips(
  WidgetTester tester, {
  bool english = true,
  int? index,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: english ? const Locale('en', 'GB') : const Locale('pl'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
      home: CookingTipsScreen(highlightIndex: index),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('only the twelve approved Polish content corrections change', () {
    const corrected = {1, 5, 13, 15, 20, 21, 23, 24, 25, 26, 28, 29};
    expect(kCookingTips.length, cookingTipsPlBefore.length);
    for (var index = 0; index < kCookingTips.length; index++) {
      expect(kCookingTips[index].icon.name, cookingTipsPlBefore[index]['icon']);
      if (!corrected.contains(index)) {
        expect(kCookingTips[index].title, cookingTipsPlBefore[index]['title']);
        expect(kCookingTips[index].tip, cookingTipsPlBefore[index]['tip']);
      } else {
        expect(
          kCookingTips[index].tip,
          isNot(cookingTipsPlBefore[index]['tip']),
        );
      }
    }
  });
  test(
    'jar-opening life hack remains in its original position in both languages',
    () {
      expect(kCookingTips[26].title, cookingTipsPlBefore[26]['title']);
      expect(kCookingTips[26].tip, contains('gumowej rękawicy'));
      expect(kCookingTipsEn[26].title, 'Get a stubborn jar open');
      expect(kCookingTipsEn[26].tip, contains('rubber glove'));
    },
  );
  test(
    'locale catalogues are cached constants rather than per-build copies',
    () {
      expect(identical(cookingTipsFor('en'), cookingTipsFor('en_GB')), true);
      expect(
        () => cookingTipsFor('en_GB').add(kCookingTips.first),
        throwsUnsupportedError,
      );
      expect(
        () => cookingTipsFor('pl').add(kCookingTips.first),
        throwsUnsupportedError,
      );
    },
  );
  test('English tips retain all 30 positions and categories', () {
    final english = cookingTipsFor('en_GB');
    expect(english, hasLength(30));
    expect(english.first.title, 'Pasta water is worth saving');
    expect(english.last.title, 'Strawberries with a twist of pepper');
    for (var index = 0; index < kCookingTips.length; index++) {
      expect(english[index].icon, kCookingTips[index].icon);
      expect(english[index].title.trim(), isNotEmpty);
      expect(english[index].tip.trim(), isNotEmpty);
    }
  });
  test('Polish and fallback tips keep the existing static catalogue', () {
    expect(identical(cookingTipsFor('pl'), kCookingTips), true);
    expect(identical(cookingTipsFor('unknown'), kCookingTips), true);
    expect(identical(cookingTipsFor('pl_PL'), cookingTipsFor('pl')), true);
  });
  for (final year in [2024, 2025, 2026]) {
    test(
      'daily rotation preserves existing calculation for every day of $year',
      () {
        for (var day = 0; day < 367; day++) {
          final now = DateTime(year, 1, 1).add(Duration(days: day));
          final original =
              now.difference(DateTime(now.year, 1, 1)).inDays %
              kCookingTips.length;
          expect(cookingTipIndexForDate(now), original);
        }
      },
    );
  }
  for (final english in [false, true]) {
    for (final index in [0, 20, 29]) {
      testWidgets(
        'selected tip is visible and highlight expires EN=$english index=$index',
        (tester) async {
          await openTips(tester, english: english, index: index);
          expect(
            find.text(english ? 'Cooking tips' : 'Porady kulinarne'),
            findsOneWidget,
          );
          final title = find.text(
            cookingTipsFor(english ? 'en_GB' : 'pl')[index].title,
          );
          final rect = tester.getRect(title);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(600));
          final card =
              find
                  .ancestor(of: title, matching: find.byType(AnimatedContainer))
                  .first;
          BorderSide border() =>
              ((tester.widget<AnimatedContainer>(card).decoration!
                              as BoxDecoration)
                          .border!
                      as Border)
                  .top;
          expect(border().color, isNot(Colors.transparent));
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          expect(border().color, Colors.transparent);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('tip list remains scrollable at 320px / 150% EN=$english', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openTips(tester, english: english, scale: 1.5);
      final last = find.text(
        cookingTipsFor(english ? 'en_GB' : 'pl').last.title,
      );
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(740));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('invalid highlight index is ignored without errors', (
    tester,
  ) async {
    await openTips(tester, index: 500);
    expect(tester.takeException(), isNull);
  });
}
