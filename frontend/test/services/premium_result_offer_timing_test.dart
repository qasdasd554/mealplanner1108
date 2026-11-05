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
  _Auth(String id)
    : user = User(
        id: id,
        email: 'result@example.test',
        householdSize: 1,
        createdAt: DateTime(2026),
      ),
      super(readToken: () async => null);
  @override
  User get currentUser => user;
}

class _Api extends ApiClient {
  int calls = 0;
  Completer<dynamic>? pending;
  _Api() : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    calls++;
    return pending?.future ?? {'allowed': true};
  }
}

void main() {
  for (final kind in [
    PremiumOfferContext.mealPlan,
    PremiumOfferContext.shoppingList,
  ]) {
    testWidgets(
      '${kind.name}: result stays visible before reading and scrolling',
      (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final auth = _Auth('first-${kind.name}');
        await auth.initialization;
        addTearDown(auth.dispose);
        final api = _Api();
        var offers = 0;
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: MaterialApp(
              home: Scaffold(
                body: PremiumOfferAfterResult(
                  resultId: 'generated-result',
                  offerContext: kind,
                  client: api,
                  present: (_, __) async {
                    offers++;
                  },
                  child: ListView(
                    controller: scroll,
                    children: const [
                      Text('Generated result'),
                      SizedBox(height: 3000),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Generated result'), findsOneWidget);
        expect(api.calls, 0);
        await tester.pump(const Duration(seconds: 12));
        expect(offers, 0); // Waiting alone must never interrupt the first view.
        scroll.jumpTo(250);
        await tester.pumpAndSettle();
        expect(
          api.calls,
          0,
        ); // Scroll restoration/programmatic motion is not reading.
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(offers, 1);
        expect(api.calls, 1);
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(api.calls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final interruption in [
    'route',
    'result',
    'session',
    'hidden',
    'dispose',
  ]) {
    testWidgets('pending result offer is dropped after $interruption changes', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final auth = _Auth('pending-$interruption');
      await auth.initialization;
      addTearDown(auth.dispose);
      final api = _Api()..pending = Completer();
      final navigator = GlobalKey<NavigatorState>();
      var offers = 0;
      var resultId = 'result-1';
      var visible = true;
      late StateSetter update;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            navigatorKey: navigator,
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Scaffold(
                  body: TickerMode(
                    enabled: visible,
                    child: PremiumOfferAfterResult(
                      resultId: resultId,
                      offerContext: PremiumOfferContext.mealPlan,
                      client: api,
                      present: (_, __) async {
                        offers++;
                      },
                      child: ListView(
                        children: const [
                          Text('Plan result'),
                          SizedBox(height: 3000),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 12));
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      if (interruption == 'route') {
        unawaited(
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Original next task')),
            ),
          ),
        );
      } else if (interruption == 'result') {
        update(() => resultId = 'result-2');
      } else if (interruption == 'session') {
        api.invalidateSession();
      } else if (interruption == 'hidden') {
        update(() => visible = false);
      } else {
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpAndSettle();
      api.pending!.complete({'allowed': true});
      await tester.pumpAndSettle();
      expect(offers, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
