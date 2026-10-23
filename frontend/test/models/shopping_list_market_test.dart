import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/shopping_list_service.dart';

Map<String, dynamic> itemPayload({
  String? currency = 'GBP',
  bool priced = true,
}) => {
  'id': 'item-1',
  'product_id': 'canonical-rice',
  'product_name': 'Long grain rice',
  'department_name': 'Cupboard',
  'department_sort_order': 1,
  'required_quantity': 650,
  'unit': 'g',
  'estimated_price': priced ? 1.8 : null,
  'is_checked': false,
  'is_from_pantry': false,
  if (currency != null) 'currency_code': currency,
  'quote_status': priced ? 'quoted' : 'unpriced',
  'price_is_estimated': true,
  'package_quantity': priced ? 500 : null,
  'package_unit': priced ? 'g' : null,
  'package_count': priced ? 2 : null,
  'purchased_quantity': priced ? 1000 : null,
  'regional_offer_id': priced ? 'offer-1' : null,
  'price_source':
      priced ? {'kind': 'estimate', 'url': 'https://example.test/rice'} : null,
};

Map<String, dynamic> listPayload({
  String? currency = 'GBP',
  bool priced = true,
}) => {
  'id': 'list-1',
  'meal_plan_id': 'plan-1',
  'store_id': 'store-1',
  'store_name': 'Tesco',
  'status': 'active',
  'total_estimated_price': priced ? 1.8 : null,
  'created_at': '2026-10-16T10:00:00Z',
  if (currency != null) 'currency_code': currency,
  'has_unpriced_items': !priced,
  'items_by_department': {
    'Cupboard': [itemPayload(currency: currency, priced: priced)],
  },
};

class _Client extends ApiClient {
  final Future<dynamic> Function() response;
  _Client(this.response) : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> get(String path, {Duration? timeout}) => response();
  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) =>
      response();
}

void main() {
  test('legacy list and all legacy items always mean PLN', () {
    final list = ShoppingList.fromJson(listPayload(currency: null));
    expect(list.currencyCode, 'PLN');
    expect(list.itemsByDepartment.values.single.single.currencyCode, 'PLN');
    expect(list.totalEstimatedPrice, 1.8);
  });

  test('GBP snapshot keeps required grams separate from purchased packs', () {
    final list = ShoppingList.fromJson(
      listPayload(),
      expectedCurrencyCode: 'GBP',
    );
    final item = list.itemsByDepartment.values.single.single;
    expect(item.productId, 'canonical-rice');
    expect(item.requiredQuantity, 650);
    expect(item.unit, 'g');
    expect(item.packageCount, 2);
    expect(item.packageQuantity, 500);
    expect(item.purchasedQuantity, 1000);
    expect(item.hasReliablePackage, isTrue);
    expect(item.priceIsEstimated, isTrue);
    expect(item.priceSource!['kind'], 'estimate');
  });

  test(
    'unpriced GBP total stays unknown even with misleading zero payload',
    () {
      final payload = listPayload(priced: false)..['total_estimated_price'] = 0;
      final list = ShoppingList.fromJson(payload);
      expect(list.totalEstimatedPrice, isNull);
      expect(list.remainingQuotedPrice, isNull);
      expect(list.hasUnknownPrices, isTrue);
      expect(
        list.itemsByDepartment.values.single.single.hasReliablePackage,
        isFalse,
      );
    },
  );

  test('unpriced GBP item ignores a fake zero amount', () {
    final payload = itemPayload(priced: false)..['estimated_price'] = 0;
    expect(ShoppingListItem.fromJson(payload).estimatedPrice, isNull);
  });

  test('zero GBP price is legal only for explicitly marked pantry items', () {
    final payload = itemPayload()..['estimated_price'] = 0;
    expect(ShoppingListItem.fromJson(payload).estimatedPrice, isNull);
    payload['quote_status'] = 'pantry';
    expect(ShoppingListItem.fromJson(payload).estimatedPrice, isNull);
    payload['is_from_pantry'] = true;
    expect(ShoppingListItem.fromJson(payload).estimatedPrice, 0);
  });

  test('a GBP observed flag requires checked source provenance', () {
    final payload = itemPayload()..['price_is_estimated'] = false;
    expect(ShoppingListItem.fromJson(payload).priceIsEstimated, isTrue);
    for (final date in [null, 'invalid', '2026-02-31']) {
      payload['price_source'] = {
        'url': 'https://example.test/rice',
        'publisher': 'Tesco',
        'checked_on': date,
      };
      expect(ShoppingListItem.fromJson(payload).priceIsEstimated, isTrue);
    }
    payload['price_source'] = {
      'url': 'https://example.test/rice',
      'publisher': 'Tesco',
      'checked_on': '2026-10-16',
    };
    expect(ShoppingListItem.fromJson(payload).priceIsEstimated, isFalse);
  });

  test('missing or inconsistent package snapshot never invents a pack', () {
    for (final invalid in [
      {'package_quantity': null},
      {'package_quantity': 0},
      {'package_count': 0},
      {'package_unit': 'opak'},
      {'purchased_quantity': 650},
    ]) {
      final payload = itemPayload()..addAll(invalid);
      expect(ShoppingListItem.fromJson(payload).hasReliablePackage, isFalse);
    }
  });

  test(
    'list rejects mixed item currencies including missing legacy currency',
    () {
      for (final currency in ['PLN', null]) {
        final payload = listPayload();
        payload['items_by_department'] = {
          'Cupboard': [itemPayload(currency: currency)],
        };
        expect(() => ShoppingList.fromJson(payload), throwsFormatException);
      }
    },
  );

  test('list rejects foreign account currency and unsupported currency', () {
    expect(
      () => ShoppingList.fromJson(listPayload(), expectedCurrencyCode: 'PLN'),
      throwsFormatException,
    );
    expect(
      () => ShoppingList.fromJson(listPayload(currency: 'USD')),
      throwsFormatException,
    );
    expect(
      () => ShoppingList.fromJson(
        listPayload(currency: null),
        expectedCurrencyCode: 'GBP',
      ),
      throwsFormatException,
    );
  });

  test('invalid price values cannot become shopping totals', () {
    for (final price in [-1, double.nan, double.infinity]) {
      expect(
        () => ShoppingList.fromJson(
          listPayload()..['total_estimated_price'] = price,
        ),
        throwsFormatException,
      );
      expect(
        () => ShoppingListItem.fromJson(
          itemPayload()..['estimated_price'] = price,
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'service accepts matching account market without changing API IDs',
    () async {
      final service = ShoppingListService(
        client: _Client(() async => listPayload()),
        expectedCurrencyCode: () => 'GBP',
      );
      final list = await service.getShoppingList('plan-1');
      expect(list.mealPlanId, 'plan-1');
      expect(list.currencyCode, 'GBP');
    },
  );

  test(
    'authorized legacy/shared read remains PLN on a British account',
    () async {
      final service = ShoppingListService(
        client: _Client(() async => listPayload(currency: null)),
        expectedCurrencyCode: () => 'GBP',
      );
      final list = await service.getShoppingList('plan-1');
      expect(list.currencyCode, 'PLN');
    },
  );

  test(
    'service rejects account market changed while request was pending',
    () async {
      var currency = 'GBP';
      final response = Completer<dynamic>();
      final service = ShoppingListService(
        client: _Client(() => response.future),
        expectedCurrencyCode: () => currency,
      );
      final pending = service.getShoppingList('plan-1');
      currency = 'PLN';
      response.complete(listPayload());
      await expectLater(pending, throwsFormatException);
    },
  );

  test(
    'own GBP list and accepted PLN share remain readable as separate lists',
    () async {
      final service = ShoppingListService(
        client: _Client(
          () async => [listPayload(), listPayload(currency: 'PLN')],
        ),
        expectedCurrencyCode: () => 'GBP',
      );
      final lists = await service.getMyLists();
      expect(lists.map((list) => list.currencyCode), ['GBP', 'PLN']);
    },
  );

  test('new list creation still rejects a foreign currency response', () async {
    final service = ShoppingListService(
      client: _Client(() async => listPayload(currency: 'PLN')),
      expectedCurrencyCode: () => 'GBP',
    );
    await expectLater(
      service.createEmptyList('store-1'),
      throwsFormatException,
    );
  });
}
