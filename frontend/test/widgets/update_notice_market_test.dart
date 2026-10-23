import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/services/update_service.dart';

void main() {
  for (final english in [false, true]) {
    testWidgets(
      'current release notice uses account language and readable bullets: $english',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale:
                english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
            home: const UpdateAvailableScreen(
              storeUrl: 'https://example.test/store',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            english ? 'An update is available' : 'Dostępna nowa wersja',
          ),
          findsOneWidget,
        );
        final body = tester
            .widgetList<Text>(find.byType(Text))
            .map((value) => value.data ?? '')
            .firstWhere((value) => value.startsWith('•'));
        expect(body.split('\n'), hasLength(5));
        expect(
          body,
          contains(
            english ? 'AI recipe ingredients' : 'dobór składników przepisów AI',
          ),
        );
        expect(
          body,
          contains(
            english ? 'Estimates are labelled' : 'Szacunki są oznaczone',
          ),
        );
        expect(
          body,
          contains(
            english ? 'generating meal plans' : 'generowania planu posiłków',
          ),
        );
        expect(body, contains(english ? 'switching shops' : 'zmianę sklepu'));
        expect(body, contains(english ? 'zero total' : 'koszt 0 zł'));
        expect(
          body,
          contains(
            english
                ? 'missing ingredient data no longer hides known values'
                : 'brak danych jednego składnika nie ukrywa znanych wartości',
          ),
        );
        expect(
          body,
          contains(english ? 'explore Premium' : 'sprawdzisz Premium'),
        );
        expect(body, isNot(contains('mealplannerpolska.pl')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
