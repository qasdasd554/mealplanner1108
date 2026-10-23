import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/screens/admin/admin_comments_screen.dart';
import 'package:smart_meal_planner/screens/admin/admin_photos_screen.dart';
import 'package:smart_meal_planner/screens/admin/admin_users_screen.dart';
import 'package:smart_meal_planner/services/moderation_service.dart';

class _Service extends ModerationService {
  final userLoads = <Completer<List<Map<String, dynamic>>>>[];
  final commentLoads = <Completer<List<Map<String, dynamic>>>>[];
  bool pendingUsers = false;
  bool pendingComments = false;
  final unban = Completer<void>();
  final approval = Completer<void>();
  int unbanCalls = 0;
  int approvalCalls = 0;
  int deleteCalls = 0;
  int rejectCalls = 0;
  final searches = <String?>[];

  @override
  Future<List<Map<String, dynamic>>> getUsers({
    String? search,
    bool onlyBanned = false,
  }) async {
    searches.add(search);
    if (!pendingUsers) return [_user('initial')];
    final response = Completer<List<Map<String, dynamic>>>();
    userLoads.add(response);
    return response.future;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllComments({String? search}) async {
    searches.add(search);
    if (!pendingComments) return [_comment('initial')];
    final response = Completer<List<Map<String, dynamic>>>();
    commentLoads.add(response);
    return response.future;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingPhotos() async => [
    {
      'recipe_id': 'recipe-id',
      'recipe_name': 'Synthetic recipe',
      'submitted_by': 'Synthetic author',
      'photo_base64': 'malformed',
      'has_current_photo': true,
    },
  ];

  @override
  Future<void> unbanUser(String userId) {
    unbanCalls++;
    return unban.future;
  }

  @override
  Future<void> approvePhoto(String recipeId) {
    approvalCalls++;
    return approval.future;
  }

  @override
  Future<void> rejectPhoto(String recipeId) async {
    rejectCalls++;
  }

  @override
  Future<void> deleteComment(String recipeId, String commentId) async {
    deleteCalls++;
  }
}

Map<String, dynamic> _user(String name) => {
  'id': 'user-$name',
  'display_name': name,
  'email': '$name@example.invalid',
  'is_banned': true,
  'role': 'user',
  'app_version': '1.0.66',
  'platform': 'android',
  'ban_reason': 'Synthetic reason',
};

Map<String, dynamic> _comment(String text) => {
  'id': 'comment-$text',
  'recipe_id': 'recipe-id',
  'recipe_name': 'Synthetic recipe',
  'text': text,
  'has_photo': true,
  'author_name': 'Synthetic author',
  'author_email': 'synthetic@example.invalid',
};

Future<void> _pump(WidgetTester tester, Widget screen, String country) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: country == 'PL' ? const Locale('pl') : const Locale('en', 'GB'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final country in ['PL', 'GB']) {
    final pl = country == 'PL';
    testWidgets('$country users shows localized moderation and bans', (
      tester,
    ) async {
      final service = _Service();
      await _pump(tester, AdminUsersScreen(service: service), country);
      expect(find.text(pl ? 'Użytkownicy' : 'Users'), findsOneWidget);
      expect(
        find.text(pl ? 'Tylko zablokowani' : 'Banned accounts only'),
        findsOneWidget,
      );
      expect(
        find.textContaining(pl ? 'Wersja: 1.0.66' : 'Version: 1.0.66'),
        findsOneWidget,
      );
      await tester.tap(find.text(pl ? 'Odblokuj' : 'Unban'));
      service.unban.complete();
      await tester.pumpAndSettle();
      expect(
        find.text(pl ? 'Konto odblokowane' : 'Account unbanned'),
        findsOneWidget,
      );
      await tester.tap(find.text(pl ? 'Zablokuj' : 'Ban'));
      await tester.pumpAndSettle();
      expect(
        find.text(pl ? 'Zablokować initial?' : 'Ban initial?'),
        findsOneWidget,
      );
      expect(
        find.text(
          pl
              ? 'Powód (widoczny dla użytkownika)'
              : 'Reason (visible to the user)',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(pl ? 'Anuluj' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$country comments shows localized confirmation and deletion', (
      tester,
    ) async {
      final service = _Service();
      await _pump(tester, AdminCommentsScreen(service: service), country);
      expect(find.text(pl ? 'Komentarze' : 'Comments'), findsOneWidget);
      expect(
        find.text(pl ? 'pod: Synthetic recipe' : 'on: Synthetic recipe'),
        findsOneWidget,
      );
      expect(
        find.text(pl ? 'zawiera zdjęcie' : 'includes a photo'),
        findsOneWidget,
      );
      await tester.tap(
        find.byTooltip(pl ? 'Usuń komentarz' : 'Delete comment'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(pl ? 'Usunąć komentarz?' : 'Delete comment?'),
        findsOneWidget,
      );
      await tester.tap(find.text(pl ? 'Usuń' : 'Delete'));
      await tester.pumpAndSettle();
      expect(service.deleteCalls, 1);
      expect(
        find.text(pl ? 'Brak komentarzy.' : 'No comments.'),
        findsOneWidget,
      );
      expect(
        find.text(pl ? 'Komentarz usunięty' : 'Comment deleted'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$country photos shows localized fallback and decisions', (
      tester,
    ) async {
      final service = _Service();
      await _pump(tester, AdminPhotosScreen(service: service), country);
      expect(
        find.text(pl ? 'Zdjęcia do akceptacji' : 'Photos awaiting review'),
        findsOneWidget,
      );
      expect(
        find.text(
          pl ? 'Zgłosił: Synthetic author' : 'Submitted by: Synthetic author',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          pl ? 'Nie udało się wczytać zdjęcia' : 'Could not load the photo',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(pl ? 'Odrzuć' : 'Reject'));
      await tester.pumpAndSettle();
      expect(service.rejectCalls, 1);
      expect(
        find.text(
          pl
              ? 'Brak zdjęć oczekujących na akceptację.'
              : 'No photos are awaiting review.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('users ignores an older search response', (tester) async {
    final service = _Service()..pendingUsers = true;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pl'),
        home: AdminUsersScreen(service: service),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'latest');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    service.userLoads[1].complete([_user('latest')]);
    await tester.pumpAndSettle();
    service.userLoads[0].complete([_user('old')]);
    await tester.pumpAndSettle();
    expect(find.text('latest'), findsNWidgets(2)); // Search field + account.
    expect(find.text('old'), findsNothing);
  });

  testWidgets('comments ignores an older failed search response', (
    tester,
  ) async {
    final service = _Service()..pendingComments = true;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pl'),
        home: AdminCommentsScreen(service: service),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'latest');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    service.commentLoads[1].complete([_comment('latest')]);
    await tester.pumpAndSettle();
    service.commentLoads[0].completeError(Exception('stale failure'));
    await tester.pumpAndSettle();
    expect(find.text('stale failure'), findsNothing);
    expect(find.text('latest'), findsNWidgets(2));
  });

  testWidgets('repeated unban before rebuild submits once', (tester) async {
    final service = _Service();
    await _pump(tester, AdminUsersScreen(service: service), 'PL');
    await tester.tap(find.text('Odblokuj'));
    await tester.tap(find.text('Odblokuj'));
    expect(service.unbanCalls, 1);
    service.unban.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('rapid delete taps open only one confirmation', (tester) async {
    final service = _Service();
    await _pump(tester, AdminCommentsScreen(service: service), 'PL');
    final position = tester.getCenter(find.byTooltip('Usuń komentarz'));
    await tester.tapAt(position);
    await tester.tapAt(position);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(service.deleteCalls, 0);
  });

  for (final country in ['PL', 'GB']) {
    testWidgets('$country ban reason is reachable above keyboard at 320px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final service = _Service();
      await _pump(tester, AdminUsersScreen(service: service), country);
      await tester.tap(find.text(country == 'PL' ? 'Odblokuj' : 'Unban'));
      service.unban.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text(country == 'PL' ? 'Zablokuj' : 'Ban'));
      await tester.pumpAndSettle();
      final reason = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(reason);
      await tester.pumpAndSettle();
      await tester.tap(reason);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      await tester.enterText(reason, 'Synthetic reason');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(country == 'PL' ? 'Anuluj' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('repeated photo approval before rebuild submits once', (
    tester,
  ) async {
    final service = _Service();
    await _pump(tester, AdminPhotosScreen(service: service), 'PL');
    await tester.tap(find.text('Zaakceptuj'));
    await tester.tap(find.text('Zaakceptuj'));
    expect(service.approvalCalls, 1);
    service.approval.complete();
    await tester.pumpAndSettle();
  });
}
