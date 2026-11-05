import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';
import 'package:smart_meal_planner/widgets/premium_comparison_table.dart';

void main() {
  tearDown(() => AppTheme.setDark(false));

  for (final market in [
    (
      locale: const Locale('pl', 'PL'),
      importCost: '2 pkt / import',
      noPoints: 'Bez punktów',
      unlimited: 'Bez limitu',
      onePerWeek: '1 / tydzień',
    ),
    (
      locale: const Locale('en', 'GB'),
      importCost: '2 points / import',
      noPoints: 'No points needed',
      unlimited: 'Unlimited',
      onePerWeek: '1 / week',
    ),
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${market.locale} comparison is truthful at 320 px, '
            'scale=$scale, dark=$dark', (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          AppTheme.setDark(dark);

          await tester.pumpWidget(
            MaterialApp(
              locale: market.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: PremiumComparisonTable(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final strings = AppLocalizations.of(
            tester.element(find.byType(PremiumComparisonTable)),
          );
          Finder comparisonRow(String label) =>
              find
                  .ancestor(of: find.text(label), matching: find.byType(Row))
                  .first;

          final publish = comparisonRow(strings.comparePublish);
          expect(
            find.descendant(of: publish, matching: find.byIcon(Icons.check)),
            findsNWidgets(2),
            reason: 'Publishing is available in both plans.',
          );
          expect(
            find.descendant(of: publish, matching: find.byIcon(Icons.remove)),
            findsNothing,
          );

          final ai = comparisonRow(strings.compareAi);
          expect(
            find.descendant(of: ai, matching: find.text(market.noPoints)),
            findsOneWidget,
            reason: 'Premium imports do not spend points.',
          );
          expect(
            find.descendant(of: ai, matching: find.text(market.importCost)),
            findsOneWidget,
            reason: 'Standard imports remain available for two points.',
          );
          expect(
            find.descendant(of: ai, matching: find.byIcon(Icons.remove)),
            findsNothing,
          );
          expect(
            tester
                .getCenter(
                  find.descendant(of: ai, matching: find.text(market.noPoints)),
                )
                .dx,
            lessThan(
              tester
                  .getCenter(
                    find.descendant(
                      of: ai,
                      matching: find.text(market.importCost),
                    ),
                  )
                  .dx,
            ),
            reason: 'The no-points value belongs to the Premium column.',
          );

          final generate = comparisonRow(strings.compareGenerate);
          expect(
            find.descendant(
              of: generate,
              matching: find.text(market.unlimited),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: generate,
              matching: find.text(market.onePerWeek),
            ),
            findsOneWidget,
            reason: 'Standard plan generation has a weekly limit.',
          );
          expect(
            tester
                .getCenter(
                  find.descendant(
                    of: generate,
                    matching: find.text(market.unlimited),
                  ),
                )
                .dx,
            lessThan(
              tester
                  .getCenter(
                    find.descendant(
                      of: generate,
                      matching: find.text(market.onePerWeek),
                    ),
                  )
                  .dx,
            ),
            reason: 'The weekly limit belongs to the Standard column.',
          );

          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text(strings.comparePrices));
          await tester.pumpAndSettle();
          expect(
            find.text(strings.comparePrices).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
