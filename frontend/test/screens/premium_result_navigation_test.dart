import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/providers/shopping_list_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/screens/meal_plan/plan_config_screen.dart';
import 'package:smart_meal_planner/services/shopping_list_service.dart';
import 'package:smart_meal_planner/widgets/dish_shopping_list_button.dart';

// Any optional claim would stall here. Result navigation must never depend on
// either the server's availability or a purchase screen being dismissed.
class _HangingHttp extends Fake implements HttpClient {
  final opens = <Completer<HttpClientRequest>>[];
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    final pending = Completer<HttpClientRequest>();
    opens.add(pending);
    return pending.future;
  }

  @override
  void close({bool force = false}) {}
}

class _Auth extends AuthProvider {
  final User user;
  _Auth(String country)
    : user = User(
        id: 'navigation-$country',
        email: 'navigation@example.test',
        countryCode: country,
        householdSize: 1,
        preferredStoreId: 'store',
        createdAt: DateTime(2026),
      ),
      super(readToken: () async => null);
  @override
  User get currentUser => user;
}

class _Stores extends StoreProvider {
  final Store store;
  _Stores(String country)
    : store = Store(
        id: 'store',
        name: 'Fixture store',
        countryCode: country,
        currencyCode: country == 'GB' ? 'GBP' : 'PLN',
        createdAt: DateTime(2026),
        updatedAt: null,
      );
  @override
  List<Store> get stores => [store];
  @override
  Store get selectedStore => store;
  @override
  void selectStoreById(String id) {}
}

class _Plans extends MealPlanProvider {
  final MealPlan plan = MealPlan(
    id: 'generated-plan',
    userId: 'fixture',
    storeId: 'store',
    durationDays: 5,
    mealsPerDay: 3,
    status: 'draft',
    entries: [],
    createdAt: DateTime(2026),
  );
  @override
  MealPlan get currentPlan => plan;
  @override
  Future<bool> generatePlan(MealPlanGenerateRequest request) async => true;
}

class _Lists extends ShoppingListProvider {
  String? loadedId;
  @override
  Future<void> loadAllLists({String? preferredListId}) async {
    loadedId = preferredListId;
  }
}

class _ListService extends ShoppingListService {
  final result = Completer<ShoppingList>();
  @override
  Future<List<ShoppingList>> getMyLists() async => [];
  @override
  Future<ShoppingList> createFromRecipes({
    required List<String> recipeIds,
    required String storeId,
    String? existingListId,
    int? servings,
  }) => result.future;
}

void main() {
  final http = _HangingHttp();
  for (final country in ['PL', 'GB']) {
    for (final kind in ['plan', 'list']) {
      testWidgets('$country $kind opens its completed result before an offer', (
        tester,
      ) async {
        await HttpOverrides.runZoned(() async {
          tester.view.physicalSize = const Size(1000, 2200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          http.opens.clear();
          addTearDown(() {
            for (final request in http.opens) {
              if (!request.isCompleted) {
                request.completeError(const HttpException('synthetic offline'));
              }
            }
          });
          final auth = _Auth(country);
          await auth.initialization;
          addTearDown(auth.dispose);
          final stores = _Stores(country);
          final plans = _Plans();
          final lists = _Lists();
          addTearDown(stores.dispose);
          addTearDown(plans.dispose);
          addTearDown(lists.dispose);
          final listService = _ListService();
          late AppLocalizations labels;
          Object? destinationTab;
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: auth),
                ChangeNotifierProvider<StoreProvider>.value(value: stores),
                ChangeNotifierProvider<MealPlanProvider>.value(value: plans),
                ChangeNotifierProvider<ShoppingListProvider>.value(
                  value: lists,
                ),
              ],
              child: MaterialApp(
                locale:
                    country == 'GB'
                        ? const Locale('en', 'GB')
                        : const Locale('pl'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (context, child) {
                  labels = AppLocalizations.of(context);
                  return MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: child!,
                  );
                },
                routes: {
                  '/plan/view':
                      (_) => const Scaffold(body: Text('Generated meal plan')),
                  '/home': (context) {
                    destinationTab = ModalRoute.of(context)!.settings.arguments;
                    return const Scaffold(body: Text('Created shopping list'));
                  },
                },
                home:
                    kind == 'plan'
                        ? const PlanConfigScreen()
                        : Scaffold(
                          body: DishShoppingListButton(
                            recipe: Recipe.fromJson({
                              'id': 'recipe',
                              'name': 'Fixture dish',
                            }),
                            service: listService,
                          ),
                        ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (kind == 'plan') {
            await tester.ensureVisible(find.text(labels.planGenerate));
            await tester.tap(find.text(labels.planGenerate));
            await tester.pumpAndSettle();
            await tester.tap(find.text(labels.planViewAction));
          } else {
            await tester.tap(find.byType(OutlinedButton));
            await tester.pump();
            expect(find.text('Created shopping list'), findsNothing);
            listService.result.complete(
              ShoppingList.fromJson({
                'id': 'new-list',
                'meal_plan_id': 'new-list-plan',
                'store_id': 'store',
                'store_name': 'Fixture store',
                'currency_code': country == 'GB' ? 'GBP' : 'PLN',
                'created_at': '2026-11-03T10:00:00Z',
                'items_by_department': <String, dynamic>{},
              }),
            );
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            find.text(
              kind == 'plan' ? 'Generated meal plan' : 'Created shopping list',
            ),
            findsOneWidget,
          );
          expect(http.opens, isEmpty);
          if (kind == 'list') {
            expect(lists.loadedId, 'new-list-plan');
            expect(destinationTab, 2);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }, createHttpClient: (_) => http);
      });
    }
  }
}
