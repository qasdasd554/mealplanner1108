import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/screens/products/products_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/product_search_service.dart';
import 'package:smart_meal_planner/services/store_service.dart';

Product _product({bool missing = false}) => Product(
  id: 'rice',
  name: 'Original product name',
  unit: 'g',
  defaultQuantity: 100,
  nutritionPer100: NutritionInfo.fromJson(
    missing ? {} : {'kcal': 300, 'protein': 10, 'fat': 2, 'carbs': 65},
  ),
);

class _Stores extends StoreProvider {
  final String country;
  _Stores(this.country);
  @override
  List<Store> get stores => [
    Store(
      id: 'shop',
      name: 'Shop',
      countryCode: country,
      currencyCode: country == 'GB' ? 'GBP' : 'PLN',
      createdAt: DateTime.utc(2026),
      updatedAt: null,
    ),
  ];
}

class _Shop extends StoreService {
  final String currency;
  final bool reviewed;
  final bool estimated;
  _Shop(this.currency, {this.reviewed = true, this.estimated = false});
  @override
  Future<List<StoreProduct>> getAllStoreProducts(
    String storeId, {
    String? search,
    String? departmentId,
  }) async => [
    StoreProduct(
      id: 'row',
      storeId: storeId,
      productId: 'rice',
      price: 2.50,
      currencyCode: currency,
      isAvailable: true,
      product: _product(),
      nameEn: reviewed && currency == 'GBP' ? 'British rice 750g' : null,
      packageQuantity: reviewed && currency == 'GBP' ? 750 : null,
      packageUnit: reviewed && currency == 'GBP' ? 'g' : null,
      priceIsEstimated: estimated,
      lastVerified: estimated ? null : DateTime.utc(2026, 10, 20),
      availabilityScope:
          reviewed && currency == 'GBP' ? 'online_catalogue' : null,
    ),
  ];
}

class _Catalogue extends ProductSearchService {
  final bool missing;
  final queries = <String>[];
  final pending = <String, Completer<List<Product>>>{};
  _Catalogue({this.missing = false});
  @override
  Future<List<Product>> list({
    String query = '',
    int skip = 0,
    int limit = 50,
  }) async {
    queries.add(query);
    return pending[query]?.future ?? [_product(missing: missing)];
  }
}

class _Client extends ApiClient {
  _Client() : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async => [
    {
      'id': 'gb-submission',
      'name': 'British submission',
      'unit': 'g',
      'review_status': 'pending',
      'submitted_country_code': 'GB',
      'submitted_price': 3.50,
    },
    {
      'id': 'pl-submission',
      'name': 'Legacy submission',
      'unit': 'g',
      'review_status': 'pending',
      'submitted_price': 4.50,
    },
  ];
}

Future<_Catalogue> _open(
  WidgetTester tester, {
  String country = 'GB',
  String currency = 'GBP',
  bool missing = false,
  bool narrow = false,
  bool reviewed = true,
  bool estimated = false,
}) async {
  if (narrow) {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  final auth = AuthProvider(readToken: () async => null);
  final stores = _Stores(country), catalogue = _Catalogue(missing: missing);
  addTearDown(auth.dispose);
  addTearDown(stores.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<StoreProvider>.value(value: stores),
      ],
      child: MaterialApp(
        locale:
            country == 'GB'
                ? const Locale('en', 'GB')
                : const Locale('pl', 'PL'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(narrow ? 1.3 : 1)),
              child: child!,
            ),
        home: ProductsScreen(
          catalogueService: catalogue,
          storeService: _Shop(
            currency,
            reviewed: reviewed,
            estimated: estimated,
          ),
          client: _Client(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return catalogue;
}

void main() {
  testWidgets('GB estimate is labelled even with dated evidence', (
    tester,
  ) async {
    await _open(tester, estimated: true);
    expect(find.text('~ £2.50'), findsOneWidget);
    expect(find.textContaining('estimated price'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('GB legacy GBP symbol without reviewed local pack is rejected', (
    tester,
  ) async {
    await _open(tester, reviewed: false);
    expect(find.text('£2.50'), findsNothing);
    expect(find.textContaining('verified price list'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('GB shop uses explicit GBP and English controls', (tester) async {
    await _open(tester);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('£2.50'), findsOneWidget);
    expect(find.text('British rice 750g'), findsOneWidget);
    expect(find.text('/ 750 g'), findsOneWidget);
    expect(find.textContaining('Online catalogue'), findsOneWidget);
    expect(find.textContaining('300 kcal'), findsNothing);
    expect(find.textContaining('zł'), findsNothing);
    expect(find.text('Earn 1 Premium point'), findsOneWidget);
    expect(find.text('Original product name'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('GB shop rejects legacy PLN rather than relabelling it', (
    tester,
  ) async {
    await _open(tester, currency: 'PLN');
    expect(find.text('~ £2.50'), findsNothing);
    expect(find.text('~ 2.50 zł'), findsNothing);
    expect(find.textContaining('verified price list'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('PL shop retains its prices and labels', (tester) async {
    await _open(tester, country: 'PL', currency: 'PLN');
    expect(find.text('2.50 zł'), findsOneWidget);
    expect(find.text('Zyskaj 1 punkt Premium'), findsOneWidget);
    expect(find.text('Sklep'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('submissions keep their own country currency and legacy PLN', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('My products'));
    await tester.pumpAndSettle();
    expect(find.text('£3.50'), findsOneWidget);
    expect(find.text('4.50 zł'), findsOneWidget);
    expect(find.text('Awaiting approval'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'catalogue unknown nutrients are not zero and search can be cleared',
    (tester) async {
      final catalogue = await _open(tester, missing: true);
      await tester.tap(find.text('Catalogue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('— kcal'), findsOneWidget);
      expect(find.textContaining('0 kcal'), findsNothing);
      final input = find.widgetWithText(
        TextField,
        'Search for a product or brand…',
      );
      await tester.enterText(input, 'rice');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(catalogue.queries.last, 'rice');
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(catalogue.queries.last, '');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('English product controls fit a narrow screen with larger text', (
    tester,
  ) async {
    await _open(tester, narrow: true);
    expect(find.text('Products'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
