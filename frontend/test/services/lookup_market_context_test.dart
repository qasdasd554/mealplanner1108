import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/product_name_lookup_service.dart';
import 'package:smart_meal_planner/utils/lookup_market_context.dart';

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
}

class _Client extends ApiClient {
  final paths = <String>[];
  _Client() : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async {
    paths.add(path);
    return [
      {
        'found': true,
        'name': 'Original label',
        'unit': 'ml',
        'barcode': '5901234123457',
        'existing_product_id': 'known',
        'serving_quantity': 500,
        'kcal_per_100': 60,
        'protein_per_100': 3,
        'price_min': 3,
        'price_max': 6,
      },
    ];
  }
}

void main() {
  for (final country in ['PL', 'GB']) {
    testWidgets(
      'lookup country $country ignores phone region and UI language',
      (tester) async {
        final auth = _Auth(country);
        addTearDown(auth.dispose);
        tester.platformDispatcher.localeTestValue =
            country == 'PL'
                ? const Locale('en', 'GB')
                : const Locale('pl', 'PL');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              locale: country == 'GB' ? const Locale('pl') : const Locale('en'),
              home: Builder(
                builder: (context) => Text(context.registeredLookupCountry),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(country), findsOneWidget);
      },
    );
  }

  testWidgets('missing account metadata keeps legacy PL, not phone GB', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'GB');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text(context.registeredLookupCountry),
        ),
      ),
    );
    expect(find.text('PL'), findsOneWidget);
  });

  test(
    'name search hides old PLN ranges for GB without losing identifiers/macros',
    () async {
      final client = _Client();
      final service = ProductNameLookupService(
        client: client,
        accountCountry: () => 'GB',
      );
      final result = (await service.search('milk')).single;
      expect(result.priceMin, isNull);
      expect(result.priceMax, isNull);
      expect(result.name, 'Original label');
      expect(result.existingProductId, 'known');
      expect(result.barcode, '5901234123457');
      expect(result.servingQuantity, 500);
      expect(result.kcalPer100, 60);
      expect(
        client.paths.single,
        '/products/search-by-name?query=milk&limit=10',
      );
      expect(client.paths.single.contains('country'), isFalse);
    },
  );

  test(
    'legacy PL name search keeps PLN range and existing request shape',
    () async {
      final client = _Client();
      final result =
          (await ProductNameLookupService(
            client: client,
          ).search('Milk & honey')).single;
      expect(result.priceMin, 3);
      expect(client.paths, hasLength(1));
      expect(
        Uri.parse(client.paths.single).queryParameters['query'],
        'Milk & honey',
      );
    },
  );

  test(
    'same service reads the current account for subsequent searches',
    () async {
      var country = 'GB';
      final service = ProductNameLookupService(
        client: _Client(),
        accountCountry: () => country,
      );
      expect((await service.search('milk')).single.priceMin, isNull);
      country = 'PL';
      expect((await service.search('milk')).single.priceMin, 3);
    },
  );
}
