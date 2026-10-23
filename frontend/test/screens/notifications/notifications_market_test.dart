import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/notification.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/screens/notifications/notifications_screen.dart';
import 'package:smart_meal_planner/services/notification_service.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';

class _Notifications extends NotificationService {
  bool fail = false;
  bool failMark = false;
  int allReads = 0;
  final reads = <String>[];
  final List<AppNotification> values;
  _Notifications(this.values);
  @override
  Future<List<AppNotification>> getNotifications() async {
    if (fail) throw Exception('Synthetic server failure');
    return values;
  }

  @override
  Future<void> markAsRead(String id) async {
    if (failMark) throw Exception('Synthetic write failure');
    reads.add(id);
  }

  @override
  Future<void> markAllAsRead() async {
    if (failMark) throw Exception('Synthetic write failure');
    allReads++;
  }
}

class _Recipes extends RecipeService {
  final reads = <String>[];
  @override
  Future<Recipe> getRecipe(String id) async {
    reads.add(id);
    return Recipe(
      id: id,
      name: 'Same recipe',
      mealType: 'obiad',
      servings: 1,
      difficulty: 'łatwy',
      isActive: true,
      tags: [],
      ingredients: [],
      nutritionTotal: NutritionInfo(
        kcal: 100,
        protein: 5,
        fat: 4,
        carbs: 11,
        fiber: 1,
      ),
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  _Notifications service, {
  bool english = true,
  Future<void> Function()? clearBadge,
  _Recipes? recipes,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    MaterialApp(
      locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: NotificationsScreen(
        service: service,
        recipeService: recipes,
        clearBadge: clearBadge ?? () async {},
      ),
      routes: {
        '/recipe/detail': (context) {
          final recipe = ModalRoute.of(context)!.settings.arguments! as Recipe;
          return Scaffold(body: Text('Recipe target: ${recipe.id}'));
        },
      },
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final english in [true, false]) {
    testWidgets(
      'notification labels and read-all action preserve semantics: $english',
      (tester) async {
        final now = DateTime.now();
        final service = _Notifications([
          AppNotification(
            id: 'notice',
            notificationType: 'shopping_list_accepted',
            message: 'Unchanged server message',
            isRead: false,
            createdAt: now.subtract(const Duration(minutes: 5)),
          ),
        ]);
        var badges = 0;
        await _open(
          tester,
          service,
          english: english,
          clearBadge: () async {
            badges++;
          },
        );
        expect(
          find.text(english ? 'Notifications' : 'Powiadomienia'),
          findsOneWidget,
        );
        expect(find.text(english ? '5 min ago' : '5 min temu'), findsOneWidget);
        expect(find.text('Unchanged server message'), findsOneWidget);
        expect(badges, 0);
        await tester.tap(
          find.text(english ? 'Mark all as read' : 'Oznacz wszystkie'),
        );
        await tester.pumpAndSettle();
        expect(service.allReads, 1);
        expect(badges, 1);
        expect(
          find.text(english ? 'Mark all as read' : 'Oznacz wszystkie'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'notification still opens its exact recipe and clears the badge',
    (tester) async {
      final service = _Notifications([
        AppNotification(
          id: 'notice',
          notificationType: 'recipe_comment',
          recipeId: 'recipe-42',
          mealPlanId: 'plan',
          commentId: 'comment',
          message: 'Open this recipe',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ]);
      final recipes = _Recipes();
      var badges = 0;
      await _open(
        tester,
        service,
        recipes: recipes,
        clearBadge: () async {
          badges++;
        },
      );
      await tester.tap(find.text('Open this recipe'));
      await tester.pumpAndSettle();
      expect(service.reads, ['notice']);
      expect(recipes.reads, ['recipe-42']);
      expect(badges, 1);
      expect(find.text('Recipe target: recipe-42'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'English errors and empty state do not change read status on failure',
    (tester) async {
      final service = _Notifications([])..fail = true;
      await _open(tester, service);
      expect(find.text('Could not load notifications'), findsOneWidget);
      service.fail = false;
      await _open(tester, _Notifications([]));
      expect(find.text('No notifications'), findsOneWidget);
      final pending = _Notifications([
        AppNotification(
          id: 'pending',
          notificationType: 'billing',
          message: 'Existing message',
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ])..failMark = true;
      await _open(tester, pending);
      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not mark all notifications as read'),
        findsOneWidget,
      );
      expect(find.text('Mark all as read'), findsOneWidget);
      expect(pending.allReads, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'English time labels use British dates without changing event timestamps',
    (tester) async {
      final now = DateTime.now();
      final old = now.subtract(const Duration(days: 10));
      final values = [
        for (final entry in [
          ('recent', now),
          ('hour', now.subtract(const Duration(hours: 2))),
          ('day', now.subtract(const Duration(days: 1, minutes: 1))),
          ('older', old),
        ])
          AppNotification(
            id: entry.$1,
            notificationType: 'billing',
            message: entry.$1,
            isRead: true,
            createdAt: entry.$2,
          ),
      ];
      await _open(tester, _Notifications(values));
      expect(find.text('just now'), findsOneWidget);
      expect(find.text('2 hr ago'), findsOneWidget);
      expect(find.text('1 day ago'), findsOneWidget);
      expect(
        find.text(DateFormat('dd/MM/yyyy', 'en_GB').format(old)),
        findsOneWidget,
      );
      expect(values.last.createdAt, old);
      expect(tester.takeException(), isNull);
    },
  );
}
