import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/providers/promotion_provider.dart';
import 'package:smart_meal_planner/providers/shopping_list_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/screens/shopping/dish_shopping_list_screen.dart';
import 'package:smart_meal_planner/screens/shopping/shopping_list_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';

var _proofFont = 'Roboto';

ThemeData _proofTheme() {
  final base = AppTheme.lightTheme;
  ButtonStyle? fonts(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) =>
          style.textStyle?.resolve(states)?.copyWith(fontFamily: _proofFont) ??
          TextStyle(fontFamily: _proofFont),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: _proofFont),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: _proofFont,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: fonts(base.elevatedButtonTheme.style),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: fonts(base.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: fonts(base.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: fonts(base.textButtonTheme.style),
    ),
  );
}

ShoppingList _list(String country, {bool priced = true}) =>
    ShoppingList.fromJson({
      'id': 'list-1',
      'meal_plan_id': 'plan-1',
      'store_id': 'store-1',
      'store_name': 'Tesco',
      'currency_code': country == 'GB' ? 'GBP' : 'PLN',
      'total_estimated_price': priced ? 1.8 : null,
      'has_unpriced_items': !priced,
      'created_at': '2026-10-16T10:00:00Z',
      'items_by_department': {
        'Cupboard': [
          {
            'id': 'item-1',
            'product_name': 'Long grain rice',
            'product_id': 'canonical-rice',
            'required_quantity': 650,
            'unit': 'g',
            'estimated_price': priced ? 1.8 : null,
            'currency_code': country == 'GB' ? 'GBP' : 'PLN',
            'quote_status': priced ? 'quoted' : 'unpriced',
            'price_is_estimated': true,
            'package_quantity': priced ? 500 : null,
            'package_unit': priced ? 'g' : null,
            'package_count': priced ? 2 : null,
            'purchased_quantity': priced ? 1000 : null,
          },
        ],
      },
    });

class _Shopping extends ShoppingListProvider {
  final ShoppingList list;
  bool substituteSuccess = false;
  _Shopping(this.list);
  @override
  ShoppingList get currentList => list;
  @override
  List<ShoppingList> get allLists => [list];
  @override
  String get selectedListId => list.mealPlanId;
  @override
  Future<void> loadAllLists({String? preferredListId}) async {}
  @override
  Future<bool> toggleItem(String itemId) async {
    final item = list.itemsByDepartment.values.single.single;
    item.isChecked = !item.isChecked;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> substituteItem(
    String itemId,
    String substituteProductId,
  ) async => substituteSuccess;
}

class _Client extends ApiClient {
  final Future<dynamic> Function() response;
  _Client(this.response) : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> get(String path, {Duration? timeout}) => response();
}

class _Promotions extends PromotionProvider {
  @override
  Future<void> ensureLoadedForStore(String? storeName) async {}
}

Widget _app(String country, Widget child) => MaterialApp(
  locale: country == 'GB' ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: const bool.fromEnvironment('UK_WRITE_UI_PROOF') ? _proofTheme() : null,
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
  home: RepaintBoundary(key: const ValueKey('shopping-ui-proof'), child: child),
);

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('UK_WRITE_UI_PROOF')) return;
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final font = File('C:/Windows/Fonts/arial.ttf');
    if (await font.exists()) {
      await (FontLoader('UKShoppingProof')
        ..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      _proofFont = 'UKShoppingProof';
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('UK_WRITE_UI_PROOF')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shopping-ui-proof')),
    );
    await tester.runAsync(() async {
      final bitmap = await boundary.toImage(pixelRatio: 1);
      final png = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../docs/uk-stage4/evidence/$name-320-text150.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
      bitmap.dispose();
    });
  }

  Future<_Shopping> openSubstitutes(
    WidgetTester tester,
    ApiClient client,
  ) async {
    final shopping = _Shopping(_list('GB'));
    final meal = MealPlanProvider();
    final store = StoreProvider();
    final promotions = _Promotions();
    addTearDown(shopping.dispose);
    addTearDown(meal.dispose);
    addTearDown(store.dispose);
    addTearDown(promotions.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ShoppingListProvider>.value(value: shopping),
          ChangeNotifierProvider<MealPlanProvider>.value(value: meal),
          ChangeNotifierProvider<StoreProvider>.value(value: store),
          ChangeNotifierProvider<PromotionProvider>.value(value: promotions),
        ],
        child: _app('GB', ShoppingListScreen(apiClient: client)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byIcon(Icons.swap_horiz),
      200,
      scrollable:
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byIcon(Icons.swap_horiz)),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pump();
    return shopping;
  }

  testWidgets('dismissed substitute sheet ignores a delayed response', (
    tester,
  ) async {
    final response = Completer<dynamic>();
    await openSubstitutes(tester, _Client(() => response.future));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    response.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'generic substitute shows estimated cost per quantity, not a fake pack',
    (tester) async {
      final shopping = await openSubstitutes(
        tester,
        _Client(
          () async => [
            {
              'id': 'generic-pasta',
              'name': 'Spaghetti',
              'currency_code': 'GBP',
              'price': 0.20,
              'price_basis': 'quantity_reference',
              'price_quantity': 100,
              'price_unit': 'g',
              'price_is_estimated': true,
            },
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Spaghetti'), findsOneWidget);
      expect(find.text('~£0.20'), findsOneWidget);
      expect(find.textContaining('100 g'), findsOneWidget);
      expect(find.textContaining('pack'), findsNothing);
      shopping.substituteSuccess = true;
      await tester.tap(find.text('Spaghetti'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a substitute'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'empty substitute response explains state instead of a blank sheet',
    (tester) async {
      await openSubstitutes(tester, _Client(() async => []));
      await tester.pumpAndSettle();
      expect(find.text('No alternatives found for this item.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed substitute never reports success or closes the picker', (
    tester,
  ) async {
    await openSubstitutes(
      tester,
      _Client(
        () async => [
          {
            'id': 'sub-1',
            'name': 'Brown rice',
            'currency_code': 'GBP',
            'price': 0.9,
            'package_quantity': 500,
            'package_unit': 'g',
          },
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('500 g pack'), findsOneWidget);
    expect(find.text('~£0.90'), findsOneWidget);
    await tester.tap(find.text('Brown rice'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Replaced with:'), findsNothing);
    expect(find.text('Choose a substitute'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'resizing an open substitute picker does not repeat its request',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final response = Completer<dynamic>();
      final client = _Client(() {
        calls++;
        return response.future;
      });
      await openSubstitutes(tester, client);
      await tester.pump(const Duration(milliseconds: 400));
      tester.view.physicalSize = const Size(700, 800);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pump();
      response.complete([]);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final country in ['PL', 'GB']) {
    for (final priced in [true, false]) {
      testWidgets(
        'dish list $country priced=$priced preserves price and package meaning at 320 px / 150% text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _app(
              country,
              DishShoppingListScreen(
                shoppingList: _list(country, priced: priced),
                friendReadOnly: true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(country == 'GB' ? 'Shopping list' : 'Lista zakupów'),
            findsOneWidget,
          );
          expect(
            find.textContaining(country == 'GB' ? 'zł' : '£'),
            findsNothing,
          );
          expect(find.textContaining('650'), findsOneWidget);
          if (country == 'GB' && priced) {
            expect(find.text('~£1.80'), findsOneWidget);
            expect(find.textContaining('Buy: 2 × 500 g'), findsOneWidget);
          }
          if (country == 'GB' && !priced) {
            expect(find.text('Price unavailable'), findsNWidgets(2));
            expect(find.textContaining('£0.00'), findsNothing);
            expect(find.textContaining('Buy:'), findsNothing);
          }
          expect(tester.takeException(), isNull);
          if (country == 'GB') {
            await capture(tester, 'dish-${priced ? 'priced' : 'unknown'}');
          }
        },
      );

      testWidgets(
        'shopping list $country priced=$priced keeps check action at 320 px / 150% text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final list = _list(country, priced: priced);
          final shopping = _Shopping(list);
          final meal = MealPlanProvider();
          final store = StoreProvider();
          final promotions = _Promotions();
          addTearDown(shopping.dispose);
          addTearDown(meal.dispose);
          addTearDown(store.dispose);
          addTearDown(promotions.dispose);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<ShoppingListProvider>.value(
                  value: shopping,
                ),
                ChangeNotifierProvider<MealPlanProvider>.value(value: meal),
                ChangeNotifierProvider<StoreProvider>.value(value: store),
                ChangeNotifierProvider<PromotionProvider>.value(
                  value: promotions,
                ),
              ],
              child: _app(country, const ShoppingListScreen()),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining(country == 'GB' ? 'zł' : '£'),
            findsNothing,
          );
          final compare = tester.getRect(
            find.widgetWithText(
              ElevatedButton,
              country == 'GB' ? 'Compare' : 'Porównaj',
            ),
          );
          final export = tester.getRect(
            find.widgetWithText(
              ElevatedButton,
              country == 'GB' ? 'Export' : 'Eksportuj',
            ),
          );
          if (country == 'GB') {
            expect(compare.left, export.left);
            expect(export.top, greaterThan(compare.bottom));
          } else {
            expect(compare.top, export.top);
          }
          if (country == 'GB' && !priced) {
            expect(find.text('Price unavailable'), findsOneWidget);
            expect(
              tester.getSize(find.text('Price unavailable')).width,
              greaterThan(200),
            );
            expect(find.textContaining('£0.00'), findsNothing);
          }
          await tester.scrollUntilVisible(
            find.byType(Checkbox),
            200,
            scrollable:
                find
                    .descendant(
                      of: find.byType(CustomScrollView),
                      matching: find.byType(Scrollable),
                    )
                    .first,
          );
          await Scrollable.ensureVisible(
            tester.element(find.byType(Checkbox)),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          if (country == 'GB' && priced) {
            expect(find.text('Buy: 2 × 500 g'), findsOneWidget);
            expect(
              tester.getSize(find.text('Long grain rice')).width,
              greaterThanOrEqualTo(90),
            );
            expect(
              find.ancestor(
                of: find.text('~£1.80'),
                matching: find.byType(Wrap),
              ),
              findsOneWidget,
            );
          }
          if (country == 'GB' && !priced) {
            expect(find.textContaining('Buy:'), findsNothing);
          }
          if (country == 'GB') {
            await capture(tester, 'shopping-${priced ? 'priced' : 'unknown'}');
          }
          await tester.tap(find.byType(Checkbox));
          await tester.pumpAndSettle();
          expect(list.checkedItems, 1);
          expect(
            list.itemsByDepartment.values.single.single.requiredQuantity,
            650,
          );
          expect(list.itemsByDepartment.values.single.single.unit, 'g');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
