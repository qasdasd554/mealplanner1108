import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/widgets/admin_market_selector.dart';

Widget _app({
  required bool isAdmin,
  bool busy = false,
  Brightness brightness = Brightness.light,
  double scale = 1,
  ValueChanged<String>? onChanged,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AdminMarketSelector(
          countryCode: 'PL',
          isAdmin: isAdmin,
          isBusy: busy,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('ordinary user never sees a market switch', (tester) async {
    await tester.pumpWidget(_app(isAdmin: false));
    expect(find.text('Rynek katalogu'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('admin switches catalogue context without editing account', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      _app(isAdmin: true, onChanged: (value) => chosen = value),
    );
    expect(
      find.text('Zmienia widok danych, nie kraj Twojego konta.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wielka Brytania').last);
    await tester.pumpAndSettle();
    expect(chosen, 'GB');
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy catalogue prevents changing context mid-operation', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      _app(isAdmin: true, busy: true, onChanged: (value) => chosen = value),
    );
    final field = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(field.onChanged, isNull);
    expect(
      find.text('Poczekaj na zakończenie bieżącej operacji.'),
      findsOneWidget,
    );
    expect(chosen, isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320px layout with large text in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(isAdmin: true, brightness: brightness, scale: 2),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Wielka Brytania'), findsWidgets);
    });
  }
}
