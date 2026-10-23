import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/promotion.dart';
import 'package:smart_meal_planner/models/recipe.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/admin/admin_panel_screen.dart';
import 'package:smart_meal_planner/services/moderation_service.dart';
import 'package:smart_meal_planner/services/notification_service.dart';
import 'package:smart_meal_planner/services/promotion_service.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  User? get currentUser => User.fromJson({
    'id': 'admin',
    'email': 'admin@example.invalid',
    'role': 'admin',
    'created_at': '2026-10-22T00:00:00',
  });
  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

class _Promotions implements PromotionService {
  final markets = <String?>[];
  @override
  Future<List<Promotion>> getPendingPromotions({String? market}) async {
    markets.add(market);
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> activeScans() async => [];
  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

class _Recipes implements RecipeService {
  final markets = <String?>[];
  @override
  Future<List<Recipe>> getPendingRecipes({String? market}) async {
    markets.add(market);
    return [
      Recipe.fromJson({
        'id': 'synthetic-recipe',
        'name': 'Unchanged recipe',
        'created_by_name': 'Unchanged author',
        'servings': 2,
        'meal_type': 'obiad',
        'difficulty': 'łatwy',
        'visibility': 'pending',
      }),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

class _Reports implements ModerationService {
  final decisions = <String>[];
  Completer<void>? pending;
  @override
  Future<List<Map<String, dynamic>>> getReports({
    String status = 'pending',
  }) async => [
    {
      'id': 'report',
      'content_type': 'comment',
      'reason': 'harassment',
      'content_preview': 'Original text',
      'details': 'Original reporter details',
      'reporter_email': 'reporter@example.invalid',
      'content_author_email': 'author@example.invalid',
    },
  ];
  @override
  Future<void> updateReportStatus(String reportId, String status) async {
    decisions.add(status);
    await pending?.future;
  }

  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

class _Notifications implements NotificationService {
  final messages = <String>[];
  Completer<int>? pending;
  @override
  Future<int> sendBroadcast(String message) async {
    messages.add(message);
    return pending == null ? 3 : pending!.future;
  }

  @override
  dynamic noSuchMethod(Invocation call) => super.noSuchMethod(call);
}

Future<void> _mount(
  WidgetTester tester,
  bool english, {
  _Promotions? promotions,
  _Reports? reports,
  _Notifications? notifications,
}) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = _Auth();
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
        home: AdminPanelScreen(
          promotionService: promotions ?? _Promotions(),
          recipeService: _Recipes(),
          moderationService: reports ?? _Reports(),
          notificationService: notifications ?? _Notifications(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    350,
    maxScrolls: 30,
    scrollable:
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final english in [false, true]) {
    testWidgets(
      'admin account language stays unchanged when selecting UK $english',
      (tester) async {
        final promotions = _Promotions();
        await _mount(tester, english, promotions: promotions);
        expect(
          find.text(english ? 'Admin panel' : 'Panel administratora'),
          findsOneWidget,
        );
        expect(
          find.text(
            english
                ? 'Recipes awaiting approval'
                : 'Przepisy oczekujące na akceptację',
          ),
          findsOneWidget,
        );
        expect(find.text('Unchanged recipe'), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(english ? 'United Kingdom' : 'Wielka Brytania').last,
        );
        await tester.pumpAndSettle();
        expect(promotions.markets, ['PL', 'GB']);
        expect(
          find.text(english ? 'Admin panel' : 'Panel administratora'),
          findsOneWidget,
        );
        await _reveal(
          tester,
          find.text(
            english
                ? 'UK promotion sources are being prepared. The Polish leaflet scanner does not create GBP promotions.'
                : 'Brytyjskie źródła promocji są w przygotowaniu. Skaner polskich gazetek nie tworzy promocji w GBP.',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'reports and broadcast preserve original authored text $english',
      (tester) async {
        final reports = _Reports();
        final notifications = _Notifications();
        await _mount(
          tester,
          english,
          reports: reports,
          notifications: notifications,
        );
        final resolved = find.text(
          english ? 'Mark as resolved' : 'Oznacz jako rozpatrzone',
        );
        await _reveal(tester, resolved);
        await tester.tap(resolved);
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 4));
        expect(reports.decisions, ['resolved']);
        final field = find.byType(TextField);
        await _reveal(tester, field);
        await tester.enterText(field, 'Original broadcast, not translated');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final send = find.text(
          english ? 'Send to everyone' : 'Wyślij do wszystkich',
        );
        await _reveal(tester, send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(notifications.messages, ['Original broadcast, not translated']);
        expect(
          find.text(
            english ? 'Sent to 3 users.' : 'Wysłano do 3 użytkowników.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('rapid broadcast submit cannot send the same message twice', (
    tester,
  ) async {
    final notifications = _Notifications()..pending = Completer<int>();
    await _mount(tester, false, notifications: notifications);
    await _reveal(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'One message');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final send = find.text('Wyślij do wszystkich');
    await _reveal(tester, send);
    await tester.tap(send);
    await tester.tap(send);
    notifications.pending!.complete(3);
    await tester.pumpAndSettle();
    expect(notifications.messages, hasLength(1));
  });
}
