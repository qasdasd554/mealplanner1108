import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';
import 'package:smart_meal_planner/widgets/planner_components.dart';
import 'package:smart_meal_planner/widgets/premium_feature_tag.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Widget child, {
    double width = 390,
    double scale = 1,
    bool dark = false,
    bool settle = true,
  }) async {
    AppTheme.setDark(dark);
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() async {
      AppTheme.setDark(false);
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  for (final width in [320.0, 390.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('controls fit $width / text $scale / dark $dark', (
          tester,
        ) async {
          await open(
            tester,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PlannerSectionHeading(title: 'Pod ręką'),
                PlannerQuickActionGrid(
                  children: [
                    PlannerQuickAction(
                      title: 'Baza produktów',
                      subtitle: 'Skanuj i wyszukuj',
                      icon: Icons.storefront_outlined,
                      onTap: () {},
                    ),
                    PlannerQuickAction(
                      title: 'Nowy plan',
                      subtitle: 'Zaplanuj posiłki',
                      icon: Icons.calendar_month_outlined,
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const DiaryEnergySummary(consumed: 1350, target: 2000),
                const SizedBox(height: 16),
                const PremiumBenefitPreview(),
                const SizedBox(height: 16),
                PremiumPlanCard(
                  title: 'Premium miesięczne',
                  price: '24,99 zł',
                  period: '/ miesiąc',
                  highlight: true,
                  hasTrial: true,
                  onTap: () {},
                ),
              ],
            ),
            width: width,
            scale: scale,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Sprawdź 7 dni za 0 zł'));
          expect(tester.takeException(), isNull);
          expect(
            find.textContaining('odnawia się automatycznie'),
            findsOneWidget,
          );
        });
      }
    }
  }

  testWidgets('benefit selector explains feature without starting purchase', (
    tester,
  ) async {
    await open(tester, const PremiumBenefitPreview());
    expect(find.byType(PremiumFeatureTag), findsOneWidget);
    await tester.tap(find.text('Skanowanie'));
    await tester.pumpAndSettle();
    expect(
      find.text('Zeskanuj całe zakupy bez zamykania aparatu'),
      findsOneWidget,
    );
    await tester.tap(find.text('Planowanie'));
    await tester.pumpAndSettle();
    expect(find.text('Zaplanuj kolejne tygodnie bez limitu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('purchase only follows explicit CTA, pending purchase disabled', (
    tester,
  ) async {
    var purchases = 0;
    await open(
      tester,
      PremiumPlanCard(
        title: 'Premium miesięczne',
        price: '24,99 zł',
        period: '/ miesiąc',
        hasTrial: true,
        onTap: () => purchases++,
      ),
    );
    expect(purchases, 0);
    await tester.tap(find.text('Sprawdź 7 dni za 0 zł'));
    expect(purchases, 1);
    await open(
      tester,
      const PremiumPlanCard(
        title: 'Premium miesięczne',
        price: '24,99 zł',
        period: '/ miesiąc',
        hasTrial: true,
        onTap: null,
        processing: true,
      ),
      settle: false,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(purchases, 1);
  });

  testWidgets('journal states excess rather than showing zero remaining', (
    tester,
  ) async {
    await open(tester, const DiaryEnergySummary(consumed: 2300, target: 2000));
    expect(find.text('300 kcal'), findsOneWidget);
    expect(find.text('powyżej celu'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
  });

  testWidgets(
    'recipe card remains readable with zero servings and large text',
    (tester) async {
      var opened = false;
      final recipe = Recipe.fromJson({
        'id': 'layout-test',
        'name': 'Makaron z pomidorami i pieczoną papryką',
        'servings': 0,
        'prep_time_min': 20,
        'difficulty': 'łatwy',
        'nutrition_total': {'kcal': 400},
      });
      await open(
        tester,
        SizedBox(
          height: 480,
          child: RecipeLibraryCard(recipe: recipe, onTap: () => opened = true),
        ),
        width: 320,
        scale: 2,
      );
      expect(find.text('400 kcal / porcję'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(recipe.name));
      expect(opened, isTrue);
    },
  );
}
