import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_planner/app.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/meal_plan_provider.dart';
import 'package:smart_meal_planner/providers/theme_provider.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  int refreshes = 0;
  void emitProfileUpdate() => notifyListeners();
  @override
  bool get isAuthenticated => true;
  @override
  User? get currentUser => null;
  @override
  Future<void> loadProfileInBackground() async {
    refreshes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Plans extends MealPlanProvider {
  int refreshes = 0;
  @override
  Future<void> loadPlans() async {
    refreshes++;
  }
}

void main() {
  for (final backgrounded in [false, true]) {
    testWidgets('refresh only after actual background, paused=$backgrounded', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final auth = _Auth();
      final plans = _Plans();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<MealPlanProvider>.value(value: plans),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: SmartMealPlannerApp(
            testRoutes: {'/': (_) => const Scaffold(body: TextField())},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      await tester.enterText(field, 'Schabowy');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        auth.refreshes,
        0,
        reason: 'initial resume is not a return from background',
      );
      final editableState = tester.state(find.byType(EditableText));
      final navigatorState = SmartMealPlannerApp.navigatorKey.currentState;
      final route = ModalRoute.of(tester.element(field));
      final cycles = backgrounded ? 3 : 30;
      for (var cycle = 0; cycle < cycles; cycle++) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        if (backgrounded) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        // Successful profile notifications must not recreate the navigator,
        // route or input field, even during a burst of Android focus events.
        auth.emitProfileUpdate();
        await tester.pump();
        expect(
          SmartMealPlannerApp.navigatorKey.currentState,
          same(navigatorState),
        );
        expect(ModalRoute.of(tester.element(field)), same(route));
        expect(tester.state(find.byType(EditableText)), same(editableState));
      }
      expect(auth.refreshes, backgrounded ? 3 : 0);
      expect(plans.refreshes, backgrounded ? 3 : 0);
      expect(
        tester.widget<TextField>(field).controller?.text ??
            tester
                .state<EditableTextState>(find.byType(EditableText))
                .widget
                .controller
                .text,
        'Schabowy',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      plans.dispose();
    });
  }
}
