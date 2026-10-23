import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/barcode_lookup_service.dart';
import 'package:smart_meal_planner/widgets/product_name_autocomplete_field.dart';
import 'package:smart_meal_planner/widgets/submit_product_sheet.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';
import '../helpers/product_form_render.dart';

class _Auth extends AuthProvider {
  final String country;
  _Auth(this.country) : super(readToken: () async => null);
  @override
  User get currentUser => User(
    id: 'user',
    email: 'test@example.test',
    countryCode: country,
    householdSize: 1,
    createdAt: DateTime.utc(2026),
  );
  @override
  Future<void> loadProfile() async {}
}

class _Stores extends StoreProvider {
  @override
  List<Store> get stores => [
    for (final country in ['GB', 'PL'])
      Store(
        id: country,
        name: 'Shop $country',
        countryCode: country,
        currencyCode: country == 'GB' ? 'GBP' : 'PLN',
        createdAt: DateTime.utc(2026),
        updatedAt: null,
      ),
  ];
}

class _UnavailableStores extends StoreProvider {
  @override
  Future<void> loadStores() async {}
}

class _Api extends ApiClient {
  final saves = <Map<String, dynamic>>[];
  bool fail = false;
  Completer<void>? pending;
  _Api() : super.forTesting(httpClient: http.Client());
  Future<dynamic> save(dynamic body) async {
    saves.add(Map<String, dynamic>.from(body as Map));
    if (pending != null) await pending!.future;
    if (fail) throw Exception('offline');
    return {'points_awarded': 1, 'premium_points': 4};
  }

  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) =>
      save(body);
  @override
  Future<dynamic> put(String path, {dynamic body}) => save(body);
}

class _Lookup extends BarcodeLookupService {
  Completer<BarcodeLookupResult>? pending;
  bool fail = false;
  @override
  Future<BarcodeLookupResult> lookup(String code) async {
    if (pending != null) return pending!.future;
    if (fail) throw Exception('offline');
    return BarcodeLookupResult(
      found: true,
      source: 'open_food_facts',
      name: code == '5901234123457' ? 'Milk' : 'Other drink',
      barcode: code,
      unit: 'ml',
      servingQuantity: code == '5901234123457' ? 500 : null,
      kcalPer100: 25,
      proteinPer100: 1,
      fatPer100: 2,
      carbsPer100: 3,
    );
  }
}

Product _product({
  String unit = 'ml',
  List<ProductMeasureOption> measures = const [],
  List<String>? requestedStoreIds,
}) => Product(
  id: 'product',
  name: 'Milk',
  unit: unit,
  defaultQuantity: 100,
  submittedCountryCode: 'GB',
  servingQuantity: 500,
  measureOptions: measures,
  requestedStoreIds: requestedStoreIds,
  nutritionPer100: NutritionInfo.fromJson({
    'kcal': 60,
    'protein': 3,
    'fat': 2,
    'carbs': 5,
  }),
);

Future<_Api> _open(
  WidgetTester tester, {
  Product? editing,
  String country = 'GB',
  Locale locale = const Locale('en', 'GB'),
  _Api? api,
  _Lookup? lookup,
  Future<String?> Function(BuildContext)? scanner,
  Size viewport = const Size(800, 2600),
  double textScale = 1,
  double keyboardBottom = 0,
  bool dark = false,
  StoreProvider? storeProvider,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  AppTheme.setDark(dark);
  addTearDown(() => AppTheme.setDark(false));
  final auth = _Auth(country), stores = storeProvider ?? _Stores();
  final client = api ?? _Api();
  addTearDown(auth.dispose);
  addTearDown(stores.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<StoreProvider>.value(value: stores),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: productFormTheme(dark),
        builder:
            (context, child) => RepaintBoundary(
              key: productFormProofKey,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  viewInsets: EdgeInsets.only(bottom: keyboardBottom),
                  viewPadding: const EdgeInsets.only(bottom: 24),
                ),
                child: child!,
              ),
            ),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder:
                            (_) => SubmitProductSheet(
                              editing: editing,
                              client: client,
                              lookupService: lookup,
                              scanner: scanner,
                            ),
                      ),
                  child: const Text('Open'),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return client;
}

Finder get _sheet => find.byType(SubmitProductSheet);
Finder _field(int index) =>
    find.descendant(of: _sheet, matching: find.byType(TextFormField)).at(index);
Future<void> _save(WidgetTester tester) async {
  final button = find.descendant(
    of: _sheet,
    matching: find.byType(FilledButton),
  );
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadProductFormFonts);
  testWidgets('offscreen invalid fields cannot bypass validation', (
    tester,
  ) async {
    final api = await _open(
      tester,
      editing: _product(),
      viewport: const Size(390, 844),
    );
    final price = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.labelText == 'Price seen in the shop (optional)',
    );
    final list =
        find.descendant(of: _sheet, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(price, 150, scrollable: list);
    await tester.enterText(price, 'NaN');
    tester.testTextInput.hide();
    final save = find.descendant(
      of: _sheet,
      matching: find.byType(FilledButton),
    );
    await tester.scrollUntilVisible(save, 200, scrollable: list);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(api.saves, isEmpty);
  });

  testWidgets('unloaded shops do not erase existing requested shop IDs', (
    tester,
  ) async {
    final api = await _open(
      tester,
      editing: _product(requestedStoreIds: ['GB']),
      storeProvider: _UnavailableStores(),
    );
    await _save(tester);
    expect(api.saves.single['store_ids'], ['GB']);
  });

  testWidgets('ambiguous legacy pack requires a physical unit before save', (
    tester,
  ) async {
    final api = await _open(tester, editing: _product(unit: 'opak'));
    await _save(tester);
    expect(api.saves, isEmpty);
    expect(find.textContaining('Choose grams or millilitres'), findsWidgets);
  });
  testWidgets('keyboard can traverse to save and activate it', (tester) async {
    final api = await _open(tester, editing: _product());
    tester
        .widget<EditableText>(find.byType(EditableText).first)
        .focusNode
        .requestFocus();
    await tester.pump();
    var onSave = false;
    for (var i = 0; i < 25 && !onSave; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      onSave =
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<FilledButton>() !=
          null;
    }
    expect(onSave, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(api.saves, hasLength(1));
  });

  testWidgets('Escape closes submission without saving', (tester) async {
    final api = await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(api.saves, isEmpty);
  });

  testWidgets('suggested nutrition is not rounded to zero during submission', (
    tester,
  ) async {
    final api = await _open(tester);
    tester
        .widget<ProductNameAutocompleteField>(
          find.byType(ProductNameAutocompleteField),
        )
        .onSelected(
          const BarcodeLookupResult(
            found: true,
            source: 'off_search',
            name: 'Low calorie drink',
            unit: 'ml',
            kcalPer100: 0.4,
            proteinPer100: 0.04,
            fatPer100: 0.02,
            carbsPer100: 0.03,
          ),
        );
    await tester.pump();
    await _save(tester);
    expect(api.saves.single['kcal_per_100'], 0.4);
    expect(api.saves.single['protein_per_100'], 0.04);
  });
  for (final locale in [const Locale('pl', 'PL'), const Locale('en', 'GB')]) {
    for (final dark in [false, true]) {
      testWidgets(
        'submission fits keyboard 320px text150 ${locale.countryCode} dark=$dark',
        (tester) async {
          await _open(
            tester,
            locale: locale,
            country: locale.countryCode!,
            viewport: const Size(320, 740),
            textScale: 1.5,
            keyboardBottom: 280,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          await captureProductForm(
            tester,
            'submit-${locale.countryCode}-${dark ? 'dark' : 'light'}-top',
          );
          final button = find.descendant(
            of: _sheet,
            matching: find.byType(FilledButton),
          );
          await tester.scrollUntilVisible(
            button,
            180,
            maxScrolls: 40,
            scrollable:
                find
                    .descendant(of: _sheet, matching: find.byType(Scrollable))
                    .first,
          );
          await tester.pumpAndSettle();
          final bounds = tester.getRect(button);
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(320));
          expect(bounds.bottom, lessThanOrEqualTo(740 - 280 - 24));
          expect(tester.takeException(), isNull);
          await captureProductForm(
            tester,
            'submit-${locale.countryCode}-${dark ? 'dark' : 'light'}-save',
          );
        },
      );
    }
  }
  testWidgets(
    'new barcode replaces prior scanned product data and unknown pack',
    (tester) async {
      final codes = ['5901234123457', '12345670'];
      final lookup = _Lookup();
      final api = await _open(
        tester,
        lookup: lookup,
        scanner: (_) async => codes.removeAt(0),
      );
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      await _save(tester);
      expect(api.saves.single['name'], 'Other drink');
      expect(api.saves.single['barcode'], '12345670');
      expect(api.saves.single.containsKey('serving_quantity'), isFalse);
      expect(api.saves.single['kcal_per_100'], 25);
    },
  );

  testWidgets(
    'failed rescan cannot submit previous product against a different barcode',
    (tester) async {
      final codes = ['5901234123457', '12345670'];
      final lookup = _Lookup();
      final api = await _open(
        tester,
        lookup: lookup,
        scanner: (_) async => codes.removeAt(0),
      );
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      lookup.fail = true;
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      await _save(tester);
      expect(api.saves, isEmpty);
      expect(tester.widget<TextFormField>(_field(0)).controller!.text, '');
    },
  );

  testWidgets('late barcode response cannot pollute a newer name selection', (
    tester,
  ) async {
    final lookup = _Lookup()..pending = Completer<BarcodeLookupResult>();
    await _open(tester, lookup: lookup, scanner: (_) async => '5901234123457');
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pump();
    tester
        .widget<ProductNameAutocompleteField>(
          find.byType(ProductNameAutocompleteField),
        )
        .onSelected(
          const BarcodeLookupResult(
            found: true,
            source: 'off_search',
            name: 'New product',
            unit: 'g',
          ),
        );
    lookup.pending!.complete(
      const BarcodeLookupResult(
        found: true,
        source: 'open_food_facts',
        name: 'Old milk',
        unit: 'ml',
        servingQuantity: 500,
        kcalPer100: 50,
        proteinPer100: 3,
        fatPer100: 2,
        carbsPer100: 5,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(_field(3)).controller!.text, '');
    expect(find.textContaining('Nutrition per 100 g'), findsOneWidget);
  });
  testWidgets('collapsing nutrition cannot bypass validation', (tester) async {
    final api = await _open(tester, editing: _product());
    await tester.ensureVisible(_field(5));
    await tester.enterText(_field(5), 'NaN');
    await tester.ensureVisible(find.text('Nutrition per 100 ml (optional)'));
    await tester.tap(find.text('Nutrition per 100 ml (optional)'));
    await tester.pumpAndSettle();
    await _save(tester);
    expect(api.saves, isEmpty);
    expect(find.text('Enter a number from 0 to 200.'), findsOneWidget);
  });

  testWidgets('GB suggestions never reinterpret the legacy PLN price range', (
    tester,
  ) async {
    await _open(tester);
    tester
        .widget<ProductNameAutocompleteField>(
          find.byType(ProductNameAutocompleteField),
        )
        .onSelected(
          const BarcodeLookupResult(
            found: true,
            source: 'off_search',
            name: 'Milk',
            unit: 'ml',
            priceMin: 2,
            priceMax: 5,
          ),
        );
    await tester.pump();
    expect(find.textContaining('Typical price range'), findsNothing);
    expect(find.textContaining('zł'), findsNothing);
  });

  testWidgets('double tap while save is pending sends only once', (
    tester,
  ) async {
    final api = _Api()..pending = Completer<void>();
    await _open(tester, editing: _product(), api: api);
    final button = find.descendant(
      of: _sheet,
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    expect(api.saves, hasLength(1));
    api.pending!.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('GB form uses English labels and GBP, not PLN suggestions', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Add your product'), findsOneWidget);
    expect(find.text('£'), findsOneWidget);
    expect(find.text('zł'), findsNothing);
  });

  testWidgets('GB submission only offers GB shops', (tester) async {
    await _open(tester);
    await tester.ensureVisible(find.byType(FilterChip).last);
    expect(find.text('Shop GB'), findsOneWidget);
    expect(find.text('Shop PL'), findsNothing);
  });

  for (final pack in [false, true]) {
    testWidgets('editing ${pack ? "pack" : "ml"} preserves ml package basis', (
      tester,
    ) async {
      final api = await _open(
        tester,
        editing: _product(
          unit: pack ? 'opak' : 'ml',
          measures:
              pack
                  ? const [
                    ProductMeasureOption(
                      code: 'opak',
                      label: 'opak',
                      baseQuantity: 500,
                      baseUnit: 'ml',
                    ),
                  ]
                  : const [],
        ),
      );
      await _save(tester);
      expect(api.saves.single['serving_unit'], 'ml');
      expect(api.saves.single['serving_quantity'], 500);
    });
  }

  testWidgets(
    'selecting another product clears missing package, brand, barcode and macros',
    (tester) async {
      await _open(tester);
      var field = tester.widget<ProductNameAutocompleteField>(
        find.byType(ProductNameAutocompleteField),
      );
      field.onSelected(
        const BarcodeLookupResult(
          found: true,
          source: 'open_food_facts',
          name: 'Milk',
          brand: 'Brand A',
          unit: 'ml',
          barcode: '5901234123457',
          servingQuantity: 500,
          kcalPer100: 60,
          proteinPer100: 3,
          fatPer100: 2,
          carbsPer100: 5,
        ),
      );
      await tester.pump();
      field.onSelected(
        const BarcodeLookupResult(
          found: true,
          source: 'off_search',
          name: 'Other product',
          unit: 'g',
        ),
      );
      await tester.pump();
      final values =
          tester
              .widgetList<TextFormField>(
                find.descendant(
                  of: _sheet,
                  matching: find.byType(TextFormField),
                ),
              )
              .map((field) => field.controller!.text)
              .toList();
      expect(values, ['Other product', '', '', '', '', '', '', '']);
      expect(find.textContaining('5901234123457'), findsNothing);
    },
  );

  for (final input in ['NaN', 'Infinity', '-1', '100001', 'abc']) {
    testWidgets('rejects invalid package size $input before API call', (
      tester,
    ) async {
      final api = await _open(tester, editing: _product());
      await tester.ensureVisible(_field(3));
      await tester.enterText(_field(3), input);
      await _save(tester);
      expect(api.saves, isEmpty);
      expect(_sheet, findsOneWidget);
    });
  }

  testWidgets(
    'rejects invalid price and macro values without silently omitting them',
    (tester) async {
      final api = await _open(tester, editing: _product());
      await tester.ensureVisible(_field(2));
      await tester.enterText(_field(2), 'NaN');
      await tester.ensureVisible(_field(4));
      await tester.enterText(_field(4), 'oops');
      await _save(tester);
      expect(api.saves, isEmpty);
    },
  );

  testWidgets(
    'empty nutrition stays absent; known zero and comma size survive',
    (tester) async {
      final api = await _open(tester);
      final field = tester.widget<ProductNameAutocompleteField>(
        find.byType(ProductNameAutocompleteField),
      );
      field.onSelected(
        const BarcodeLookupResult(
          found: true,
          source: 'off_search',
          name: 'Zero protein drink',
          unit: 'ml',
          kcalPer100: 20,
          proteinPer100: 0,
        ),
      );
      await tester.pump();
      await tester.ensureVisible(_field(3));
      await tester.enterText(_field(3), '330,5');
      await _save(tester);
      expect(api.saves.single['serving_quantity'], 330.5);
      expect(api.saves.single['serving_unit'], 'ml');
      expect(api.saves.single['protein_per_100'], 0);
      expect(api.saves.single.containsKey('fat_per_100'), isFalse);
      expect(api.saves.single.containsKey('carbs_per_100'), isFalse);
    },
  );

  testWidgets('failed save preserves input and allows retry', (tester) async {
    final client = _Api()..fail = true;
    await _open(tester, api: client, editing: _product());
    await _save(tester);
    expect(_sheet, findsOneWidget);
    expect(tester.widget<TextFormField>(_field(0)).controller!.text, 'Milk');
    client.fail = false;
    await _save(tester);
    expect(client.saves, hasLength(2));
    expect(_sheet, findsNothing);
  });
}
