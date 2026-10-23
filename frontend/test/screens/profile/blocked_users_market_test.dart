import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/profile/blocked_users_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  bool failLoad = false;
  String? unblocked;
  @override
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    if (failLoad) throw ApiException(504, 'Synthetic timeout');
    return [
      {'blocked_user_id': 'other', 'blocked_display_name': 'Alex'},
    ];
  }

  @override
  Future<bool> unblockUser(String id) async {
    unblocked = id;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(
  WidgetTester tester,
  _Auth auth, {
  bool english = true,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const BlockedUsersScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final english in [true, false]) {
    testWidgets('unblocking uses the same ID and interaction: $english', (
      tester,
    ) async {
      final auth = _Auth();
      await _open(tester, auth, english: english);
      expect(
        find.text(english ? 'Blocked users' : 'Zablokowani użytkownicy'),
        findsOneWidget,
      );
      await tester.tap(find.text(english ? 'Unblock' : 'Odblokuj'));
      await tester.pumpAndSettle();
      expect(auth.unblocked, 'other');
      expect(
        find.text(
          english
              ? 'You have not blocked anyone yet.'
              : 'Nie zablokowałeś jeszcze nikogo.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Alex'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('timeout is English and loading ends', (tester) async {
    await _open(tester, _Auth()..failLoad = true);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text(
        'The server did not respond in time. Please try again shortly.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
