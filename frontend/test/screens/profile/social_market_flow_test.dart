import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/friend.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/models/shopping_list.dart';
import 'package:smart_meal_planner/screens/profile/friend_detail_screen.dart';
import 'package:smart_meal_planner/screens/profile/friends_screen.dart';
import 'package:smart_meal_planner/screens/shopping/dish_shopping_list_screen.dart';
import 'package:smart_meal_planner/screens/shopping/pending_shares_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/friend_service.dart';
import 'package:smart_meal_planner/services/shopping_list_service.dart';

FriendEntry _entry(String id, {String? direction}) => FriendEntry(
  connectionId: 'connection-$id',
  userId: id,
  displayName: 'Alex $id',
  status: direction == null ? 'accepted' : 'pending',
  direction: direction,
  createdAt: DateTime.utc(2026),
);

class _Friends extends FriendService {
  bool fail = false;
  String? invited;
  String? accepted;
  String? cancelled;
  final recipeReads = <String>[];
  final listReads = <String>[];
  bool emptyDetails = false;
  @override
  Future<List<FriendEntry>> getFriends() async {
    if (fail) throw ApiException(503, 'Synthetic service failure');
    return [_entry('friend')];
  }

  @override
  Future<List<FriendEntry>> getInvitations() async => [
    if (accepted == null) _entry('incoming', direction: 'incoming'),
    if (cancelled == null) _entry('outgoing', direction: 'outgoing'),
  ];
  @override
  Future<FriendEntry> invite(String identifier) async {
    invited = identifier;
    return _entry('new', direction: 'outgoing');
  }

  @override
  Future<void> accept(String id) async {
    accepted = id;
  }

  @override
  Future<void> declineOrCancel(String id) async {
    cancelled = id;
  }

  @override
  Future<List<Recipe>> getRecipes(String id) async {
    recipeReads.add(id);
    if (fail) throw ApiException(503, 'Synthetic service failure');
    return emptyDetails
        ? []
        : [
          Recipe(
            id: 'recipe',
            name: 'Alex’s soup',
            mealType: 'obiad',
            servings: 2,
            difficulty: 'łatwy',
            prepTimeMin: 10,
            cookTimeMin: 20,
            isActive: true,
            tags: [],
            ingredients: [],
            nutritionTotal: NutritionInfo(
              kcal: 400,
              protein: 20,
              fat: 10,
              carbs: 50,
              fiber: 3,
            ),
          ),
        ];
  }

  @override
  Future<List<ShoppingList>> getShoppingLists(String id) async {
    listReads.add(id);
    return emptyDetails
        ? []
        : [
          ShoppingList(
            id: 'list',
            mealPlanId: 'plan',
            storeId: 'store',
            storeName: 'Tesco',
            status: 'pending',
            totalEstimatedPrice: null,
            currencyCode: 'GBP',
            createdAt: DateTime.utc(2026),
            itemsByDepartment: {
              'Produce': [
                ShoppingListItem(
                  id: 'item',
                  productName: 'Carrots',
                  departmentName: 'Produce',
                  departmentSortOrder: 1,
                  requiredQuantity: 500,
                  unit: 'g',
                  currencyCode: 'GBP',
                  isChecked: true,
                ),
              ],
            },
          ),
        ];
  }
}

class _Shares extends ShoppingListService {
  bool fail = false;
  String? accepted;
  String? declined;
  ShoppingListShare get share => ShoppingListShare(
    id: 'share',
    mealPlanId: 'plan',
    status: 'pending',
    createdAt: DateTime.utc(2026),
    sharedByName: 'Alex',
  );
  @override
  Future<List<ShoppingListShare>> getPendingShares() async {
    if (fail) throw ApiException(504, 'Synthetic timeout');
    return [share];
  }

  @override
  Future<ShoppingListShare> acceptShare(String id) async {
    accepted = id;
    return share;
  }

  @override
  Future<void> deleteShare(String id) async {
    declined = id;
  }
}

Future<void> _open(
  WidgetTester tester,
  Widget screen, {
  bool english = true,
  bool narrow = false,
}) async {
  if (narrow) {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    MaterialApp(
      locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
            child: child!,
          ),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'editing then cancelling invitation survives the closing animation',
    (tester) async {
      final service = _Friends();
      await _open(tester, FriendsScreen(service: service), english: false);
      await tester.tap(find.text('Zaproś'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Alex');
      await tester.tap(find.text('Anuluj').last);
      await tester.pumpAndSettle();
      expect(service.invited, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  for (final english in [true, false]) {
    testWidgets(
      'invitations use the same connection IDs in both locales: $english',
      (tester) async {
        final service = _Friends();
        await _open(
          tester,
          FriendsScreen(service: service),
          english: english,
          narrow: true,
        );
        expect(find.text(english ? 'Friends' : 'Znajomi'), findsOneWidget);
        await tester.tap(find.byTooltip(english ? 'Accept' : 'Przyjmij'));
        await tester.pumpAndSettle();
        expect(service.accepted, 'connection-incoming');
        expect(
          find.text(
            english ? 'Invitation accepted.' : 'Zaproszenie zostało przyjęte.',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text(english ? 'Cancel' : 'Anuluj'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(english ? 'Cancel' : 'Anuluj'));
        await tester.pumpAndSettle();
        expect(service.cancelled, 'connection-outgoing');
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'friend detail preserves data and read-only list navigation: $english',
      (tester) async {
        final service = _Friends();
        await _open(
          tester,
          FriendDetailScreen(friend: _entry('friend'), service: service),
          english: english,
        );
        expect(service.recipeReads, ['friend']);
        expect(service.listReads, ['friend']);
        expect(find.text('Alex’s soup'), findsOneWidget);
        expect(
          find.text(english ? '30 min • lunch' : '30 min • obiad'),
          findsOneWidget,
        );
        await tester.tap(
          find.text(english ? 'Shopping list' : 'Lista zakupów'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(english ? '1 of 1 bought' : '1 z 1 kupione'),
          findsOneWidget,
        );
        await tester.tap(find.text('Tesco'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DishShoppingListScreen>(
                find.byType(DishShoppingListScreen),
              )
              .friendReadOnly,
          isTrue,
        );
        expect(find.textContaining('£0'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    for (final accept in [true, false]) {
      testWidgets(
        'shared-list invitation retains explicit consent $english/$accept',
        (tester) async {
          final service = _Shares();
          await _open(
            tester,
            PendingSharesScreen(service: service),
            english: english,
            narrow: true,
          );
          expect(
            find.text(
              english
                  ? 'Alex shared a shopping list with you'
                  : 'Alex udostępnił Ci listę zakupów',
            ),
            findsOneWidget,
          );
          await tester.tap(
            find.byTooltip(
              accept
                  ? (english ? 'Accept' : 'Zaakceptuj')
                  : (english ? 'Decline' : 'Odrzuć'),
            ),
          );
          await tester.pumpAndSettle();
          expect(accept ? service.accepted : service.declined, 'share');
          expect(accept ? service.declined : service.accepted, isNull);
          expect(
            find.text(
              english
                  ? 'No pending invitations.'
                  : 'Brak oczekujących zaproszeń.',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('English friend and share failures keep a working retry', (
    tester,
  ) async {
    final friends = _Friends()..fail = true;
    await _open(tester, FriendsScreen(service: friends));
    expect(
      find.textContaining('The service is temporarily unavailable.'),
      findsOneWidget,
    );
    friends.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Alex friend'), findsOneWidget);
    final shares = _Shares()..fail = true;
    await _open(tester, PendingSharesScreen(service: shares));
    expect(
      find.textContaining('The server did not respond in time.'),
      findsOneWidget,
    );
    shares.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Alex shared a shopping list with you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
