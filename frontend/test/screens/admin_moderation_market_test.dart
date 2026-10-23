import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/screens/admin/admin_all_recipes_screen.dart';
import 'package:smart_meal_planner/screens/admin/admin_products_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';

Map<String, dynamic> _product(String id) => {
  'id': id,
  'name': 'Original product $id',
  'brand': 'Unchanged brand',
  'unit': 'g',
  'submitted_price': 1.99,
  'nutrition_per_100': {'kcal': 120, 'protein': 3, 'fat': 4, 'carbs': 15},
};
Map<String, dynamic> _recipe(int i) => {
  'id': 'recipe-$i',
  'name': 'Original recipe $i',
  'visibility': i == 0 ? 'private' : 'public',
  'created_by_name': 'Original author',
  'servings': 2,
  'created_at': '2026-10-22T00:00:00',
};

class _Client implements ApiClient {
  final gets = <String>[];
  final writes = <String>[];
  Future<dynamic> Function(String)? read;
  Completer<dynamic>? pendingWrite;
  bool failWrite = false;
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async {
    gets.add(path);
    if (read != null) return read!(path);
    if (path.startsWith('/products')) return [_product('test')];
    final skip = int.parse(Uri.parse(path).queryParameters['skip']!);
    return skip == 0 ? List.generate(31, _recipe) : [_recipe(30)];
  }

  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    writes.add(path);
    if (failWrite) throw ApiException(503, 'synthetic failure');
    return pendingWrite?.future;
  }

  @override
  Future<dynamic> delete(String path) async {
    writes.add(path);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

class _Observer extends NavigatorObserver {
  Route<dynamic>? last;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    last = route;
  }
}

Future<void> _mount(
  WidgetTester tester,
  Widget screen,
  bool english, {
  NavigatorObserver? observer,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      navigatorObservers: [if (observer != null) observer],
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
      home: screen,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  for (final products in [false, true]) {
    testWidgets(
      'old market response cannot replace the new moderation queue products=$products',
      (tester) async {
        final old = Completer<dynamic>();
        final client =
            _Client()
              ..read = (path) async {
                if (Uri.parse(path).queryParameters['market'] == 'PL')
                  return old.future;
                return products ? [_product('gb')] : [_recipe(99)];
              };
        Widget screen(String market) =>
            products
                ? AdminProductsScreen(market: market, client: client)
                : AdminAllRecipesScreen(market: market, client: client);
        await _mount(tester, screen('PL'), false, settle: false);
        await _mount(tester, screen('GB'), false);
        expect(
          find.text(products ? 'Original product gb' : 'Original recipe 99'),
          findsOneWidget,
        );
        old.complete(products ? [_product('pl')] : [_recipe(0)]);
        await tester.pumpAndSettle();
        expect(
          find.text(products ? 'Original product gb' : 'Original recipe 99'),
          findsOneWidget,
        );
        expect(
          find.text(products ? 'Original product pl' : 'Original recipe 0'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final english in [false, true]) {
    for (final market in ['PL', 'GB']) {
      testWidgets(
        'product actions follow account language, not market $market/$english',
        (tester) async {
          final client = _Client();
          await _mount(
            tester,
            AdminProductsScreen(market: market, client: client),
            english,
          );
          expect(client.gets.single, '/products/admin/pending?market=$market');
          expect(
            find.text(english ? 'Submitted products' : 'Zgłoszone produkty'),
            findsOneWidget,
          );
          expect(find.text('Original product test'), findsOneWidget);
          final approve = find.text(english ? 'Approve' : 'Akceptuj');
          expect(approve.hitTestable(), findsOneWidget);
          await tester.tap(approve);
          await tester.pumpAndSettle();
          expect(client.writes, ['/products/admin/test/review?approve=true']);
          expect(find.text('Original product test'), findsNothing);
          expect(
            find.text(
              english
                  ? 'Product added to catalogue'
                  : 'Produkt dodany do katalogu',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('failed moderation preserves product and supports retry $english', (
      tester,
    ) async {
      final client = _Client()..failWrite = true;
      await _mount(
        tester,
        AdminProductsScreen(market: 'GB', client: client),
        english,
      );
      final reject = find.text(english ? 'Reject' : 'Odrzuć');
      await tester.tap(reject);
      await tester.pumpAndSettle();
      expect(find.text('Original product test'), findsOneWidget);
      expect(
        find.text(
          english
              ? 'The service is temporarily unavailable. Please try again shortly.'
              : 'Usługa jest chwilowo niedostępna. Spróbuj ponownie za chwilę.',
        ),
        findsOneWidget,
      );
      client.failWrite = false;
      await tester.tap(reject);
      await tester.pumpAndSettle();
      expect(
        client.writes,
        List.filled(2, '/products/admin/test/review?approve=false'),
      );
      expect(find.text('Original product test'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'all recipes keep 30-row pagination and localized labels $english',
      (tester) async {
        final client = _Client();
        await _mount(
          tester,
          AdminAllRecipesScreen(market: 'GB', client: client),
          english,
        );
        expect(
          find.text(
            english ? 'All user recipes' : 'Wszystkie przepisy użytkowników',
          ),
          findsOneWidget,
        );
        expect(find.text(english ? 'Private' : 'Prywatny'), findsOneWidget);
        final more = find.text(english ? 'Show more' : 'Pokaż więcej');
        await tester.scrollUntilVisible(more, 400, maxScrolls: 40);
        await tester.pumpAndSettle();
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(client.gets, [
          '/recipes/admin/all-user-recipes?skip=0&limit=31&market=GB',
          '/recipes/admin/all-user-recipes?skip=30&limit=31&market=GB',
        ]);
        await tester.scrollUntilVisible(find.text('Original recipe 30'), 300);
        expect(find.text('Original recipe 30'), findsOneWidget);
        expect(more, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'private recipe still opens its original detail argument $english',
      (tester) async {
        final observer = _Observer();
        await _mount(
          tester,
          AdminAllRecipesScreen(market: 'PL', client: _Client()),
          english,
          observer: observer,
        );
        await tester.tap(find.text('Original recipe 0'));
        final argument = observer.last!.settings.arguments as Recipe;
        expect(argument.id, 'recipe-0');
        expect(argument.name, 'Original recipe 0');
        expect(argument.visibility, 'private');
        // No real detail HTTP call: assert navigation before building its next frame.
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'delete recipe can be cancelled without changing data $english',
      (tester) async {
        final client = _Client();
        await _mount(
          tester,
          AdminAllRecipesScreen(market: 'PL', client: client),
          english,
        );
        await tester.tap(
          find.byTooltip(english ? 'Delete recipe' : 'Usuń przepis').first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text(english ? 'Delete recipe?' : 'Usunąć przepis?'),
          findsOneWidget,
        );
        await tester.tap(find.text(english ? 'Cancel' : 'Anuluj'));
        await tester.pumpAndSettle();
        expect(client.writes, isEmpty);
        expect(find.text('Original recipe 0'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('duplicate review before rebuild sends only one decision', (
    tester,
  ) async {
    final client = _Client()..pendingWrite = Completer<dynamic>();
    await _mount(tester, AdminProductsScreen(client: client), false);
    final approve = find.text('Akceptuj');
    await tester.tap(approve);
    await tester.tap(approve);
    client.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(client.writes, hasLength(1));
  });
}
