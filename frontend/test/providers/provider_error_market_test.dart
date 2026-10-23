import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/l10n/app_localizations_pl.dart';
import 'package:smart_meal_planner/models/food_log.dart';
import 'package:smart_meal_planner/models/meal_plan.dart';
import 'package:smart_meal_planner/models/promotion.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/models/store.dart';
import 'package:smart_meal_planner/providers/food_log_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/providers/promotion_provider.dart';
import 'package:smart_meal_planner/providers/shopping_list_provider.dart';
import 'package:smart_meal_planner/providers/store_provider.dart';
import 'package:smart_meal_planner/providers/wellness_provider.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/food_log_service.dart';
import 'package:smart_meal_planner/services/meal_plan_service.dart';
import 'package:smart_meal_planner/services/promotion_service.dart';
import 'package:smart_meal_planner/services/shopping_list_service.dart';
import 'package:smart_meal_planner/services/store_service.dart';
import 'package:smart_meal_planner/services/wellness_service.dart';
import 'package:smart_meal_planner/utils/error_utils.dart';

class FailedStores extends StoreService {
  final Object failure;
  FailedStores(this.failure);
  @override
  Future<List<Store>> getStores() async => throw failure;
}

class FailedPlans extends MealPlanService {
  final Object failure;
  FailedPlans(this.failure);
  @override
  Future<List<MealPlan>> getPlans() async => throw failure;
}

class FailedLists extends ShoppingListService {
  final Object failure;
  FailedLists(this.failure);
  @override
  Future<List<ShoppingList>> getMyLists() async => throw failure;
}

class FailedFood extends FoodLogService {
  final Object failure;
  FailedFood(this.failure);
  @override
  Future<List<FoodLogEntry>> getLogsForDate(
    DateTime date,
    String token,
  ) async => throw failure;
  @override
  Future<DailySummary> getDailySummary(DateTime date, String token) async =>
      throw failure;
}

class FailedWellness extends WellnessService {
  final Object failure;
  FailedWellness(this.failure);
  @override
  Future<DailyWellness> getForDate(DateTime date) async => throw failure;
}

class FailedPromotions extends PromotionService {
  final Object failure;
  FailedPromotions(this.failure);
  @override
  Future<List<Promotion>> getPromotions({
    String? storeName,
    String? search,
  }) async => throw failure;
}

Future<List<String?>> loadFailedProviders(
  Object failure,
  ErrorStringsResolver? resolver,
) async {
  final stores = StoreProvider(
    service: FailedStores(failure),
    errorStrings: resolver,
  );
  final plans = MealPlanProvider(
    service: FailedPlans(failure),
    errorStrings: resolver,
  );
  final lists = ShoppingListProvider(
    shoppingListService: FailedLists(failure),
    errorStrings: resolver,
  );
  final food = FoodLogProvider(
    service: FailedFood(failure),
    readToken: () async => 'synthetic-session',
    errorStrings: resolver,
  );
  final wellness = WellnessProvider(
    service: FailedWellness(failure),
    errorStrings: resolver,
  );
  final promotions = PromotionProvider(
    service: FailedPromotions(failure),
    errorStrings: resolver,
  );
  await Future.wait([
    stores.loadStores(),
    plans.loadPlans(),
    lists.loadAllLists(),
    food.fetchLogsForDate(DateTime(2026, 10, 22)),
    wellness.loadForDate(DateTime(2026, 10, 22)),
    promotions.loadPromotions(),
  ]);
  final messages = [
    stores.errorMessage,
    plans.errorMessage,
    lists.errorMessage,
    food.error,
    wellness.errorMessage,
    promotions.error,
  ];
  for (final provider in [stores, plans, lists, food, wellness, promotions]) {
    provider.dispose();
  }
  return messages;
}

class DeferredStores extends StoreService {
  final pending = Completer<List<Store>>();
  @override
  Future<List<Store>> getStores() => pending.future;
}

void main() {
  final errors = <Object>[
    ApiException(401, 'technical authorization'),
    ApiException(429, 'technical rate limit'),
    ApiException(503, 'technical unavailable'),
    ApiException(504, 'technical deadline'),
    ApiException(500, 'technical server'),
    TimeoutException('timed out'),
    const SocketException('connection refused'),
    const FormatException('bad response'),
  ];
  for (final country in ['PL', 'GB']) {
    final AppLocalizations strings =
        country == 'GB' ? AppLocalizationsEnGb() : AppLocalizationsPl();
    for (var index = 0; index < errors.length; index++) {
      test(
        '$country provider errors use the account language: $index',
        () async {
          final messages = await loadFailedProviders(
            errors[index],
            () => strings,
          );
          expect(
            messages,
            everyElement(friendlyError(errors[index], strings: strings)),
          );
        },
      );
    }
    test(
      '$country server-authored validation text remains untouched',
      () async {
        const message =
            'Original server validation detail: synthetic ingredient';
        final messages = await loadFailedProviders(
          ApiException(422, message),
          () => strings,
        );
        expect(messages, everyElement(message));
      },
    );
    test('$country missing session explains the diary action', () async {
      final food = FoodLogProvider(
        readToken: () async => null,
        errorStrings: () => strings,
      );
      addTearDown(food.dispose);
      await food.fetchLogsForDate(DateTime(2026, 10, 22));
      expect(
        food.error,
        country == 'GB'
            ? 'Sign in to view your diary.'
            : 'Musisz być zalogowany, aby zobaczyć dziennik.',
      );
      expect(
        await food.addManualEntry(
          mealType: 'obiad',
          foodName: 'Synthetic',
          calories: 1,
          protein: 1,
          carbs: 1,
          fat: 1,
        ),
        isFalse,
      );
      expect(
        food.error,
        country == 'GB'
            ? 'Sign in to add an entry.'
            : 'Musisz być zalogowany, aby dodać wpis.',
      );
    });
  }
  test('legacy providers retain exactly the Polish fallback', () async {
    final failure = ApiException(503, 'raw');
    expect(
      await loadFailedProviders(failure, null),
      everyElement(friendlyError(failure)),
    );
  });
  test(
    'same provider reads the new account language without losing state',
    () async {
      var strings = AppLocalizationsPl() as AppLocalizations;
      final stores = StoreProvider(
        service: FailedStores(ApiException(503, 'raw')),
        errorStrings: () => strings,
      );
      addTearDown(stores.dispose);
      await stores.loadStores();
      expect(stores.errorMessage, strings.errorUnavailable);
      strings = AppLocalizationsEnGb();
      stores.clear();
      await stores.loadStores();
      expect(stores.errorMessage, strings.errorUnavailable);
    },
  );
  test(
    'late error after clear cannot read or restore the old account message',
    () async {
      final service = DeferredStores();
      var reads = 0;
      final stores = StoreProvider(
        service: service,
        errorStrings: () {
          reads++;
          return AppLocalizationsEnGb();
        },
      );
      addTearDown(stores.dispose);
      final pending = stores.loadStores();
      stores.clear();
      service.pending.completeError(ApiException(503, 'raw'));
      await pending;
      expect(stores.errorMessage, isNull);
      expect(reads, 0);
    },
  );
  test(
    'explicit promotion screen language takes precedence over fallback',
    () async {
      final promotions = PromotionProvider(
        service: FailedPromotions(ApiException(503, 'raw')),
        errorStrings: () => AppLocalizationsPl(),
      );
      addTearDown(promotions.dispose);
      await promotions.loadPromotions(strings: AppLocalizationsEnGb());
      expect(promotions.error, AppLocalizationsEnGb().errorUnavailable);
    },
  );
}
