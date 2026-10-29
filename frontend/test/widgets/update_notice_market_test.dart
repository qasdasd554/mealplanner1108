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
        expect(body.split('\n'), hasLength(7));
        expect(body, contains(english ? 'splash screen' : 'Ekran startowy'));
        expect(
          body,
          contains(
            english ? 'Catalogue alternatives' : 'Zamienniki katalogowe',
          ),
        );
        expect(
          body,
          contains(
            english
                ? 'Repeated shopping ingredients'
                : 'powtarzające się składniki',
          ),
        );
        expect(body, contains(english ? 'Eggs' : 'Jajka'));
        expect(
          body,
          contains(
            english
                ? 'recalculates quantities and prices'
                : 'przelicza ilości i ceny',
          ),
        );
        expect(body, contains(english ? 'batch scan' : 'skanowaniu seryjnym'));
        expect(
          body,
          contains(
            english
                ? 'does not add calories twice'
                : 'nie nalicza kalorii drugi raz',
          ),
        );
        expect(
          body,
          contains(english ? 'purchased-item checks' : 'zaznaczanie zakupów'),
        );
        expect(
          body,
          contains(english ? 'allergen settings' : 'ustawienia alergenów'),
        );
        expect(body, contains(english ? 'food diary' : 'w dzienniku'));
        expect(
          body,
          contains(english ? 'calorie calculations' : 'obliczanie kalorii'),
        );
        expect(
          body,
          contains(english ? 'household plans' : 'planach dla kilku osób'),
        );
        expect(body, contains(english ? 'shop offers' : 'ofert sklepu'));
        expect(body, isNot(contains('mealplannerpolska.pl')));
        expect(
          body,
          contains(english ? 'after changing a meal' : 'po zamianie dania'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
