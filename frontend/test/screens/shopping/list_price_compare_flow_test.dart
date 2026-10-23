import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/providers/promotion_provider.dart';
import 'package:smart_meal_planner/providers/shopping_list_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/screens/shopping/shopping_list_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/price_compare_service.dart';
import 'package:smart_meal_planner/screens/shopping/price_compare_screen.dart';

class _Auth extends AuthProvider {
  User user;
  _Auth({String country = 'GB'})
    : user = User(
        id: 'user-1',
        email: 'local@example.test',
        countryCode: country,
        householdSize: 1,
        createdAt: DateTime.utc(2026, 10, 19),
      ),
      super(readToken: () async => null);
  @override
  User get currentUser => user;
}

Map<String, dynamic> _listPayload({String currency = 'GBP'}) => {
  'id': 'database-row-id',
  'meal_plan_id': 'technical-api-list-id',
  'store_id': 'old-store',
  'store_name': 'Tesco',
  'currency_code': currency,
  'total_estimated_price': 4,
  'created_at': '2026-10-19T10:00:00Z',
  'items_by_department': {
    'Cupboard': [
      {
        'id': 'manual-item',
        'product_name': 'Manual extra',
        'product_id': 'rice',
        'required_quantity': 500,
        'unit': 'g',
        'currency_code': currency,
        'estimated_price': 4,
        'quote_status': 'quoted',
        'is_checked': true,
        'is_from_pantry': false,
        'package_quantity': 500,
        'package_count': 1,
        'purchased_quantity': 500,
        'package_unit': 'g',
      },
    ],
  },
};

Map<String, dynamic> _comparison({
  String currency = 'GBP',
  bool complete = true,
}) => {
  'store_id': 'new-store',
  'store_name': 'Aldi',
  'currency_code': currency,
  'total_price': complete ? 4 : null,
  'is_complete': complete,
  'missing_products': complete ? <String>[] : ['Manual extra'],
  'is_cheapest': complete,
  'savings_vs_most_expensive': 0,
  'items': <dynamic>[],
};

class _Client extends ApiClient {
  final gets = <String>[];
  final puts = <String>[];
  Future<dynamic> Function(String)? onGet;
  Future<dynamic> Function(String, dynamic)? onPut;
  _Client() : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async {
    gets.add(path);
    if (onGet != null) return onGet!(path);
    if (path.startsWith('/price-compare/shopping-list/')) {
      return [_comparison()];
    }
    throw ApiException(404, 'No plan entries for a technical/manual list');
  }

  @override
  Future<dynamic> put(String path, {dynamic body, Duration? timeout}) async {
    puts.add(path);
    return onPut != null
        ? onPut!(path, body)
        : (_listPayload()..['store_id'] = 'new-store');
  }
}

class _Shopping extends ShoppingListProvider {
  final ShoppingList list;
  int loads = 0;
  _Shopping(this.list);
  @override
  ShoppingList get currentList => list;
  @override
  List<ShoppingList> get allLists => [list];
  @override
  String get selectedListId => list.mealPlanId;
  @override
  Future<void> loadAllLists({String? preferredListId}) async {
    loads++;
  }
}

class _Plans extends MealPlanProvider {
  int switches = 0;
  @override
  Future<bool> updateStore(String planId, String storeId) async {
    switches++;
    throw StateError('Plan regeneration must not run for a list');
  }
}

class _Promotions extends PromotionProvider {
  @override
  Future<void> ensureLoadedForStore(String? storeName) async {}
}

Future<({_Auth auth, _Shopping shopping, _Plans plans})> _open(
  WidgetTester tester,
  _Client client, {
  String country = 'GB',
  String currency = 'GBP',
}) async {
  final auth = _Auth(country: country);
  await auth.initialization;
  final shopping = _Shopping(
    ShoppingList.fromJson(_listPayload(currency: currency)),
  );
  final plans = _Plans();
  final stores = StoreProvider();
  final promotions = _Promotions();
  addTearDown(auth.dispose);
  addTearDown(shopping.dispose);
  addTearDown(plans.dispose);
  addTearDown(stores.dispose);
  addTearDown(promotions.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ShoppingListProvider>.value(value: shopping),
        ChangeNotifierProvider<MealPlanProvider>.value(value: plans),
        ChangeNotifierProvider<StoreProvider>.value(value: stores),
        ChangeNotifierProvider<PromotionProvider>.value(value: promotions),
      ],
      child: MaterialApp(
        locale:
            country == 'GB'
                ? const Locale('en', 'GB')
                : const Locale('pl', 'PL'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ShoppingListScreen(
          priceCompareService: PriceCompareService(client: client),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final compare = find.widgetWithIcon(ElevatedButton, Icons.store);
  await Scrollable.ensureVisible(tester.element(compare), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(compare);
  await tester.pumpAndSettle();
  return (auth: auth, shopping: shopping, plans: plans);
}

void main() {
  for (final kind in ['manual', 'merged']) {
    testWidgets(
      'GB $kind list compares current list rows instead of plan entries',
      (tester) async {
        final client = _Client();
        final state = await _open(tester, client);
        expect(client.gets, [
          '/price-compare/shopping-list/technical-api-list-id',
        ]);
        expect(
          client.gets.any((path) => path.startsWith('/meal-plans')),
          isFalse,
        );
        expect(find.text('Aldi'), findsOneWidget);
        expect(state.plans.switches, 0);
        expect(
          state.shopping.list.itemsByDepartment.values.single.single.isChecked,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'list switch uses list endpoint, reloads shopping and never regenerates plan',
    (tester) async {
      final client = _Client();
      final state = await _open(tester, client);
      final before = state.shopping.loads;
      await tester.tap(find.text('Aldi'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Switch list to this shop'),
      );
      await tester.pumpAndSettle();
      expect(client.puts, ['/shopping-lists/technical-api-list-id/store']);
      expect(state.plans.switches, 0);
      expect(state.shopping.loads, before + 1);
      expect(find.byType(PriceCompareScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed target quote stays on comparison without success or reload',
    (tester) async {
      final client =
          _Client()
            ..onPut =
                (_, __) async =>
                    throw ApiException(
                      409,
                      'The current basket cannot be fully priced.',
                    );
      final state = await _open(tester, client);
      final before = state.shopping.loads;
      await tester.tap(find.text('Aldi'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Switch list to this shop'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PriceCompareScreen), findsOneWidget);
      expect(
        find.text('The current basket cannot be fully priced.'),
        findsOneWidget,
      );
      expect(state.shopping.loads, before);
      expect(state.plans.switches, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('accepted GBP share on Polish account retains GBP list route', (
    tester,
  ) async {
    final client = _Client();
    final state = await _open(tester, client, country: 'PL');
    expect(client.gets, ['/price-compare/shopping-list/technical-api-list-id']);
    expect(find.text('Aldi'), findsOneWidget);
    expect(state.plans.switches, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Polish recipe list compares saved rows instead of a hidden plan',
    (tester) async {
      final client =
          _Client()..onGet = (_) async => [_comparison(currency: 'PLN')];
      await _open(tester, client, country: 'PL', currency: 'PLN');
      expect(client.gets, [
        '/price-compare/shopping-list/technical-api-list-id',
      ]);
      expect(find.text('Aldi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('incomplete list has no store switch action', (tester) async {
    final client =
        _Client()..onGet = (_) async => [_comparison(complete: false)];
    await _open(tester, client);
    await tester.tap(find.text('Aldi'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(OutlinedButton, 'Switch list to this shop'),
      findsNothing,
    );
    expect(find.text('Total unavailable'), findsOneWidget);
    expect(client.puts, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'dismissing pending list switch does not update disposed context',
    (tester) async {
      final pending = Completer<dynamic>();
      final client = _Client()..onPut = (_, __) => pending.future;
      final state = await _open(tester, client);
      final before = state.shopping.loads;
      await tester.tap(find.text('Aldi'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Switch list to this shop'),
      );
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      pending.complete(_listPayload()..['store_id'] = 'new-store');
      await tester.pumpAndSettle();
      expect(state.shopping.loads, before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'session changed during switch cannot show success for previous account',
    (tester) async {
      final pending = Completer<dynamic>();
      final client = _Client()..onPut = (_, __) => pending.future;
      final state = await _open(tester, client);
      final before = state.shopping.loads;
      await tester.tap(find.text('Aldi'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Switch list to this shop'),
      );
      await tester.pump();
      state.auth.user = User(
        id: 'another-user',
        email: 'another@example.test',
        countryCode: 'GB',
        householdSize: 1,
        createdAt: DateTime.utc(2026, 10, 19),
      );
      pending.complete(_listPayload()..['store_id'] = 'new-store');
      await tester.pumpAndSettle();
      expect(find.byType(PriceCompareScreen), findsOneWidget);
      expect(find.text('Aldi'), findsNothing);
      expect(state.shopping.loads, before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'list switch rejects a stale response belonging to another list',
    () async {
      final client =
          _Client()
            ..onPut =
                (_, __) async =>
                    (_listPayload()
                      ..['meal_plan_id'] = 'other-list'
                      ..['store_id'] = 'new-store');
      await expectLater(
        PriceCompareService(client: client).switchShoppingListStore(
          'technical-api-list-id',
          'new-store',
          expectedCurrencyCode: 'GBP',
        ),
        throwsFormatException,
      );
    },
  );
}
