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
        expect(body.split('\n'), hasLength(4));
        expect(body, contains(english ? 'substitutes' : 'zamienników'));
        expect(body, contains(english ? 'catalogue prices' : 'ceny produktów'));
        expect(
          body,
          contains(english ? 'quantity conversions' : 'przeliczanie ilości'),
        );
        expect(body, contains(english ? 'UK foods' : 'w UK'));
        expect(
          body,
          contains(english ? 'estimated prices' : 'ceny szacunkowe'),
        );
        expect(body, isNot(contains('mealplannerpolska.pl')));
        expect(
          body,
          contains(english ? 'quantity-based costs' : 'wyceny porcji'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
