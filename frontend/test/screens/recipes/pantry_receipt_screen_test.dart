import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/market_locale.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/recipes/pantry_receipt_screen.dart';
import 'package:smart_meal_planner/services/pantry_receipt_service.dart';

class _Auth extends AuthProvider {
  _Auth(String country, bool premium)
    : currentUser = User(
        id: 'receipt-fixture',
        email: 'receipt@example.test',
        householdSize: 1,
        isPremium: premium,
        countryCode: country,
        createdAt: DateTime.utc(2026),
      ),
      super(readToken: () async => null);

  @override
  final User currentUser;
}

class _Picker extends ImagePicker {
  var opened = false;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    opened = true;
    return XFile.fromData(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aKmQAAAAASUVORK5CYII=',
      ),
      mimeType: 'image/png',
    );
  }
}

class _Receipts extends PantryReceiptService {
  final calls = <List<ReceiptSelection>>[];
  final String food;
  _Receipts(this.food);

  @override
  Future<ReceiptPreview> scan(bytes) async => (
    token: 'fixture',
    items: [
      (name: food, quantity: 150.0, unit: 'g'),
      (name: 'Pasta', quantity: null, unit: 'opak'),
    ],
  );

  @override
  Future<ReceiptSave> save(String token, List<ReceiptSelection> items) async {
    expect(token, 'fixture');
    calls.add(items);
    return (savedCount: 1, skippedCount: 0, alreadySaved: false);
  }
}

void main() {
  for (final country in ['PL', 'GB']) {
    Widget app(_Auth auth, _Picker picker, _Receipts service) =>
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            locale: localeForMarket(accountCountry: country),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        final result = await Navigator.of(
                          context,
                        ).push<ReceiptSave>(
                          MaterialPageRoute(
                            builder:
                                (_) => PantryReceiptScreen(
                                  service: service,
                                  picker: picker,
                                ),
                          ),
                        );
                        if (context.mounted && result != null) {
                          showReceiptSaved(context, result);
                        }
                      },
                      child: const Text('Open fixture'),
                    ),
                  ),
            ),
          ),
        );

    testWidgets(
      '$country receipt review saves the corrected, selected grocery',
      (tester) async {
        tester.view.physicalSize = const Size(320, 690);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = _Auth(country, true);
        final picker = _Picker();
        final food = country == 'GB' ? 'Carrots' : 'Marchew';
        final service = _Receipts(food);
        final strings = stringsForAccountCountry(country);
        addTearDown(auth.dispose);
        await tester.pumpWidget(app(auth, picker, service));
        await tester.tap(find.text('Open fixture'));
        await tester.pumpAndSettle();
        final gallery = find.text(strings.productLabelGallery);
        await tester.scrollUntilVisible(gallery, 150);
        await tester.tap(gallery);
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.receiptReadAction));
        await tester.pumpAndSettle();
        expect(find.text(strings.receiptReviewTitle), findsOneWidget);
        expect(find.text(food), findsOneWidget);
        final missing = find.text(strings.receiptQuantityUnreadable);
        final list =
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first;
        await tester.scrollUntilVisible(missing, 150, scrollable: list);
        expect(missing, findsOneWidget);
        final quantity = find.byKey(const ValueKey('receipt-quantity-0'));
        await tester.scrollUntilVisible(quantity, -150, scrollable: list);
        await tester.enterText(quantity, '175,5');
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.receiptSaveAction));
        await tester.pumpAndSettle();
        expect(service.calls.single, [(index: 0, quantity: 175.5, unit: 'g')]);
        expect(find.text(strings.receiptSaved(1)), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$country Standard account sees the Premium preview without camera access',
      (tester) async {
        final auth = _Auth(country, false);
        final picker = _Picker();
        final service = _Receipts('Fixture');
        final strings = stringsForAccountCountry(country);
        addTearDown(auth.dispose);
        await tester.pumpWidget(app(auth, picker, service));
        await tester.tap(find.text('Open fixture'));
        await tester.pumpAndSettle();
        expect(find.text(strings.receiptPremiumMessage), findsOneWidget);
        expect(find.text(strings.productLabelTakePhoto), findsNothing);
        expect(find.text(strings.productLabelGallery), findsNothing);
        expect(picker.opened, isFalse);
      },
    );
  }
}
