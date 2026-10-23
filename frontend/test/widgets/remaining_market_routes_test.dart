import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/shopping_list_provider.dart';
import 'package:smart_meal_planner/screens/shopping/export_list_screen.dart';
import 'package:smart_meal_planner/services/product_name_lookup_service.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';
import 'package:smart_meal_planner/widgets/add_product_sheet.dart';
import 'package:smart_meal_planner/widgets/recipe_approval_bar.dart';

Recipe _recipe(String id) => Recipe(
  id: id,
  name: 'Nazwa użytkownika bez tłumaczenia',
  mealType: 'obiad',
  servings: 1,
  difficulty: 'łatwy',
  nutritionTotal: NutritionInfo(
    kcal: 100,
    protein: 1,
    fat: 1,
    carbs: 1,
    fiber: 1,
  ),
  isActive: true,
  tags: [],
  ingredients: [],
  visibility: 'pending',
);

class _Auth extends ChangeNotifier implements AuthProvider {
  _Auth({this.admin = true});
  final bool admin;
  @override
  User get currentUser => User(
    id: 'synthetic-user',
    email: 'synthetic@example.invalid',
    displayName: 'Synthetic author',
    householdSize: 1,
    countryCode: 'GB',
    role: admin ? 'admin' : 'user',
    createdAt: DateTime(2026),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recipes extends RecipeService {
  final approval = Completer<Recipe>();
  int calls = 0;
  @override
  Future<Recipe> approveRecipe(String recipeId) {
    calls++;
    return approval.future;
  }

  @override
  Future<Recipe> rejectRecipe(String recipeId) async => _recipe(recipeId);
}

class _Lookup extends ProductNameLookupService {
  final calls = <String>[];
  final responses = <Completer<List<BarcodeLookupResult>>>[];
  @override
  Future<List<BarcodeLookupResult>> search(String query, {int limit = 10}) {
    calls.add(query);
    final response = Completer<List<BarcodeLookupResult>>();
    responses.add(response);
    return response.future;
  }
}

class _Shopping extends ChangeNotifier implements ShoppingListProvider {
  final add = Completer<bool>();
  final productIds = <String>[];
  final names = <String>[];
  @override
  String? get errorMessage => null;
  @override
  Future<bool> addProduct(
    String productId, {
    double quantity = 1,
    String unit = 'szt',
  }) {
    productIds.add(productId);
    return add.future;
  }

  @override
  Future<bool> addCustomItem(
    String name, {
    double quantity = 1,
    String unit = 'szt',
  }) {
    names.add(name);
    return add.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(
  Widget home, {
  String country = 'GB',
  _Auth? auth,
  _Shopping? shopping,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: auth ?? _Auth()),
    ChangeNotifierProvider<ShoppingListProvider>.value(
      value: shopping ?? _Shopping(),
    ),
  ],
  child: MaterialApp(
    locale: country == 'GB' ? const Locale('en', 'GB') : const Locale('pl'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  ),
);

Future<void> _sheet(
  WidgetTester tester,
  _Lookup lookup,
  _Shopping shopping,
  String country,
) async {
  await tester.pumpWidget(
    _app(
      Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed:
                    () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => AddProductSheet(lookupService: lookup),
                    ),
                child: const Text('Open synthetic sheet'),
              ),
            ),
      ),
      country: country,
      shopping: shopping,
    ),
  );
  await tester.tap(find.text('Open synthetic sheet'));
  await tester.pumpAndSettle();
}

ShoppingList _list() => ShoppingList(
  id: 'synthetic-list',
  mealPlanId: 'synthetic-plan',
  storeId: 'synthetic-store',
  storeName: 'Synthetic store',
  status: 'pending',
  totalEstimatedPrice: null,
  itemsByDepartment: {
    'Inne': [
      ShoppingListItem(
        id: 'synthetic-item',
        productName: 'Żółty ser użytkownika',
        departmentName: 'Inne',
        departmentSortOrder: 99,
        requiredQuantity: 1,
        unit: 'opak',
        isChecked: false,
      ),
    ],
  },
  createdAt: DateTime(2026),
);

void main() {
  for (final country in ['PL', 'GB']) {
    testWidgets(
      '$country delivery destinations are unchanged PL or disabled UK placeholders',
      (tester) async {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: ExportListDialog(
                shoppingList: _list(),
                accountCountry: country,
              ),
            ),
            country: country,
          ),
        );
        await tester.pumpAndSettle();
        if (country == 'GB') {
          for (final name in ['Deliveroo', 'Tesco']) {
            final tile = find.widgetWithText(ListTile, 'Open $name');
            expect(tile, findsOneWidget);
            expect(tester.widget<ListTile>(tile).enabled, isFalse);
            expect(tester.widget<ListTile>(tile).onTap, isNull);
          }
          expect(find.text('Coming soon'), findsNWidgets(2));
          expect(find.text('Open Glovo'), findsNothing);
          expect(find.text('Open Żabka Jush'), findsNothing);
        } else {
          for (final name in ['Żabka Jush', 'Glovo']) {
            final tile = find.widgetWithText(ListTile, 'Otwórz $name');
            expect(tester.widget<ListTile>(tile).enabled, isTrue);
            expect(tester.widget<ListTile>(tile).onTap, isNotNull);
          }
          expect(find.text('Wkrótce'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final country in ['PL', 'GB']) {
    final pl = country == 'PL';
    testWidgets('$country approval controls and result are localized', (
      tester,
    ) async {
      final service = _Recipes();
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: RecipeApprovalBar(recipe: _recipe('one'), service: service),
          ),
          country: country,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          pl
              ? 'Ten przepis czeka na Twoją akceptację do wspólnego katalogu'
              : 'This recipe is awaiting your approval for the shared catalogue',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(pl ? 'Zaakceptuj' : 'Approve'));
      service.approval.complete(_recipe('one'));
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(
        find.text(pl ? 'Przepis zaakceptowany' : 'Recipe approved'),
        findsOneWidget,
      );
    });

    testWidgets('$country add sheet labels and custom text remain usable', (
      tester,
    ) async {
      final lookup = _Lookup();
      final shopping = _Shopping();
      await _sheet(tester, lookup, shopping, country);
      expect(
        find.text(pl ? 'Dodaj produkt do listy' : 'Add a product to the list'),
        findsOneWidget,
      );
      expect(
        find.text(
          pl
              ? 'Wpisz co najmniej 2 znaki, żeby wyszukać produkt.'
              : 'Enter at least 2 characters to search for a product.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Żółty ser');
      await tester.pump();
      await tester.tap(
        find.text(pl ? 'Dodaj wpisaną pozycję' : 'Add the item you entered'),
      );
      expect(shopping.names, ['Żółty ser']);
      shopping.add.complete(true);
      await tester.pumpAndSettle();
      expect(
        find.text(pl ? 'Dodano: Żółty ser' : 'Added: Żółty ser'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$country export labels and copied content use locale not product translation',
      (tester) async {
        String? clipboard;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData')
              clipboard = (call.arguments as Map)['text'] as String;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          _app(
            Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed:
                          () => showDialog<void>(
                            context: context,
                            builder:
                                (_) => ExportListDialog(
                                  shoppingList: _list(),
                                  accountCountry: country,
                                ),
                          ),
                      child: const Text('Open export'),
                    ),
                  ),
            ),
            country: country,
          ),
        );
        await tester.tap(find.text('Open export'));
        await tester.pumpAndSettle();
        expect(
          find.text(pl ? 'Eksportuj listę' : 'Export list'),
          findsOneWidget,
        );
        await tester.tap(
          find.text(pl ? 'Kopiuj do schowka' : 'Copy to clipboard'),
        );
        await tester.pumpAndSettle();
        expect(
          clipboard,
          contains(
            pl
                ? 'Moja lista zakupów: Synthetic store'
                : 'My shopping list: Synthetic store',
          ),
        );
        expect(clipboard, contains(pl ? '[Inne]' : '[Other]'));
        expect(clipboard, contains('Żółty ser użytkownika'));
        expect(clipboard, contains(pl ? '1.0 opak' : '1.0 pack'));
        expect(
          find.text(pl ? 'Skopiowano do schowka!' : 'Copied to clipboard!'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('approval double taps send one mutation', (tester) async {
    final service = _Recipes();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: RecipeApprovalBar(recipe: _recipe('one'), service: service),
        ),
        country: 'PL',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zaakceptuj'));
    await tester.tap(find.text('Zaakceptuj'));
    expect(service.calls, 1);
    service.approval.complete(_recipe('one'));
    await tester.pumpAndSettle();
  });

  testWidgets('a different pending recipe resets previous moderation state', (
    tester,
  ) async {
    final service = _Recipes();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: RecipeApprovalBar(recipe: _recipe('one'), service: service),
        ),
        country: 'PL',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zaakceptuj'));
    service.approval.complete(_recipe('one'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: RecipeApprovalBar(recipe: _recipe('two'), service: service),
        ),
        country: 'PL',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Zaakceptuj'), findsOneWidget);
  });

  testWidgets(
    'changed query invalidates old response before debounce elapses',
    (tester) async {
      final lookup = _Lookup();
      await _sheet(tester, lookup, _Shopping(), 'PL');
      await tester.enterText(find.byType(TextField), 'old');
      await tester.pump(const Duration(milliseconds: 400));
      expect(lookup.calls, ['old']);
      await tester.enterText(find.byType(TextField), 'new');
      lookup.responses.single.complete([
        const BarcodeLookupResult(
          found: true,
          name: 'Old result',
          source: 'catalog',
          existingProductId: 'old-id',
        ),
      ]);
      await tester.pump();
      expect(find.text('Old result'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('old approval response cannot resolve a different recipe', (
    tester,
  ) async {
    final service = _Recipes();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: RecipeApprovalBar(recipe: _recipe('one'), service: service),
        ),
        country: 'PL',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zaakceptuj'));
    await tester.pump();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: RecipeApprovalBar(recipe: _recipe('two'), service: service),
        ),
        country: 'PL',
      ),
    );
    await tester.pumpAndSettle();
    service.approval.complete(_recipe('one'));
    await tester.pumpAndSettle();
    expect(find.text('Zaakceptuj'), findsOneWidget);
    expect(find.text('Przepis zaakceptowany'), findsNothing);
  });

  testWidgets('ordinary accounts never see recipe moderation controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: RecipeApprovalBar(recipe: _recipe('one'), service: _Recipes()),
        ),
        auth: _Auth(admin: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets(
    'closing export while checking another app ignores the late result',
    (tester) async {
      final response = Completer<bool>();
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'canLaunch') return response.future;
        return false;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        _app(
          Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (_) => ExportListDialog(shoppingList: _list()),
                        ),
                    child: const Text('Open export'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Open export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Glovo'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      response.complete(false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('This app is not installed.'), findsNothing);
    },
  );

  testWidgets('add sheet remains usable with a keyboard on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final shopping = _Shopping();
    await _sheet(tester, _Lookup(), shopping, 'GB');
    expect(tester.takeException(), isNull);
    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, 'x');
    await tester.pump();
    final add = find.text('Add the item you entered');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    expect(add.hitTestable(), findsOneWidget);
    await tester.tap(add);
    expect(shopping.names, ['x']);
    shopping.add.complete(true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated product taps do not add duplicate list items', (
    tester,
  ) async {
    final lookup = _Lookup();
    final shopping = _Shopping();
    await _sheet(tester, lookup, shopping, 'PL');
    await tester.enterText(find.byType(TextField), 'Milk');
    await tester.pump(const Duration(milliseconds: 400));
    lookup.responses.single.complete([
      const BarcodeLookupResult(
        found: true,
        name: 'Milk',
        source: 'catalog',
        existingProductId: 'milk-id',
      ),
    ]);
    await tester.pumpAndSettle();
    final tile = find.widgetWithText(ListTile, 'Milk');
    await tester.tap(tile);
    await tester.tap(tile);
    expect(shopping.productIds, ['milk-id']);
    shopping.add.complete(true);
    await tester.pumpAndSettle();
  });
}
