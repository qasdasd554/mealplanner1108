import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/models/premium_offer.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/contextual_premium_offer_service.dart';

class _Auth extends AuthProvider {
  User user;
  _Auth(String country, String id, {bool premium = false})
    : user = User(
        id: id,
        email: 'synthetic@example.test',
        countryCode: country,
        householdSize: 1,
        createdAt: DateTime.now(),
        isPremium: premium,
      ),
      super(readToken: () async => null);
  @override
  User get currentUser => user;
}

class _Api extends ApiClient {
  int calls = 0;
  Completer<dynamic>? pending;
  bool allowed = true;
  _Api() : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    calls++;
    return pending?.future ?? {'allowed': allowed};
  }
}

void main() {
  for (final country in ['PL', 'GB']) {
    testWidgets('$country daily offers show at most once per login session', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final auth = _Auth(country, 'once-$country');
      await auth.initialization;
      addTearDown(auth.dispose);
      final api = _Api();
      late BuildContext target;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                target = context;
                return const Scaffold();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var shows = 0;
      Future<void> present(
        BuildContext context,
        PremiumOfferContext kind,
      ) async {
        shows++;
      }

      expect(
        await ContextualPremiumOfferService.maybeShow(
          target,
          PremiumOfferContext.recipe,
          client: api,
          present: present,
        ),
        isTrue,
      );
      expect(
        await ContextualPremiumOfferService.maybeShow(
          target,
          PremiumOfferContext.shoppingList,
          client: api,
          present: present,
        ),
        isFalse,
      );
      expect(shows, 1);
      expect(api.calls, 1);
      api.invalidateSession();
      expect(
        await ContextualPremiumOfferService.maybeShow(
          target,
          PremiumOfferContext.recipe,
          client: api,
          present: present,
        ),
        isTrue,
      );
      expect(shows, 2); // New login; the real backend still enforces 24h.
    });
  }
  testWidgets(
    'typing, active premium and obsolete claims never interrupt the user',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final auth = _Auth('GB', 'typing-test');
      await auth.initialization;
      addTearDown(auth.dispose);
      final api = _Api();
      late BuildContext target;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                target = context;
                return const Scaffold(body: TextField());
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(
        await ContextualPremiumOfferService.maybeShow(
          target,
          PremiumOfferContext.recipe,
          client: api,
        ),
        isFalse,
      );
      expect(api.calls, 0);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      api.pending = Completer();
      var shows = 0;
      final claim = ContextualPremiumOfferService.maybeShow(
        target,
        PremiumOfferContext.recipe,
        client: api,
        present: (_, __) async {
          shows++;
        },
      );
      expect(api.calls, 1);
      api.invalidateSession();
      api.pending!.complete({'allowed': true});
      expect(await claim, isFalse);
      expect(shows, 0);
      auth.user = User(
        id: 'premium',
        email: 'premium@example.test',
        countryCode: 'GB',
        householdSize: 1,
        createdAt: DateTime.now(),
        isPremium: true,
      );
      expect(
        await ContextualPremiumOfferService.maybeShow(
          target,
          PremiumOfferContext.recipe,
          client: api,
        ),
        isFalse,
      );
      expect(api.calls, 1);
    },
  );
}
