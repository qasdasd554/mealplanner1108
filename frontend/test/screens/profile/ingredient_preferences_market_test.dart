import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/ingredient_preferences.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/profile/ingredient_preferences_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/ingredient_preferences_service.dart';
import 'package:smart_meal_planner/services/product_search_service.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  final bool premium;
  final bool english;
  _Auth({required this.premium, required this.english});
  @override
  User get currentUser => User(
    id: 'actor',
    email: 'test@example.invalid',
    createdAt: DateTime.utc(2026),
    isPremium: premium,
    householdSize: 1,
    countryCode: english ? 'GB' : 'PL',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences extends IngredientPreferencesService {
  int loads = 0;
  IngredientPreferences? saved;
  bool failSave = false;
  @override
  Future<IngredientPreferences> load() async {
    loads++;
    return const IngredientPreferences();
  }

  @override
  Future<IngredientPreferences> save(IngredientPreferences value) async {
    if (failSave) throw ApiException(503, 'Synthetic service failure');
    saved = value;
    return value;
  }
}

class _Search extends ProductSearchService {
  String? query;
  @override
  Future<List<Product>> search(String text, {int limit = 20}) async {
    query = text;
    return [
      for (final approved in [true, false])
        Product(
          id: approved ? 'broccoli' : 'pending',
          name: approved ? 'Broccoli' : 'Unreviewed ingredient',
          unit: 'g',
          defaultQuantity: 100,
          reviewStatus: approved ? 'approved' : 'pending',
          nutritionPer100: NutritionInfo(
            kcal: 34,
            protein: 3,
            fat: 0.4,
            carbs: 5,
            fiber: 3,
          ),
        ),
    ];
  }
}

Future<void> _open(
  WidgetTester tester,
  _Preferences service,
  _Search search, {
  bool english = true,
  bool premium = true,
  bool narrow = false,
}) async {
  if (narrow) {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(premium: premium, english: english),
      child: MaterialApp(
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
        home: IngredientPreferencesScreen(
          service: service,
          searchService: search,
        ),
        routes: {
          '/premium':
              (_) => const Scaffold(body: Text('Existing Premium screen')),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> chooseBroccoli(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(TextField));
  await tester.enterText(find.byType(TextField), 'broccoli');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.widgetWithText(ListTile, 'Broccoli'));
  await tester.tap(find.widgetWithText(ListTile, 'Broccoli'));
  await tester.pumpAndSettle();
}

void main() {
  for (final english in [true, false]) {
    testWidgets(
      'ingredient preferences preserve selection and payload: $english',
      (tester) async {
        final service = _Preferences();
        final search = _Search();
        await _open(tester, service, search, english: english);
        expect(
          find.text(
            english ? 'Ingredient preferences' : 'Preferencje składników',
          ),
          findsOneWidget,
        );
        expect(service.loads, 1);
        await chooseBroccoli(tester);
        expect(search.query, 'broccoli');
        expect(find.text('Unreviewed ingredient'), findsNothing);
        final dislike = find.text(
          english ? 'Add to: Dislike' : 'Dodaj do: Nie lubię',
        );
        await tester.ensureVisible(dislike);
        await tester.tap(dislike);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.widgetWithText(ListTile, 'Broccoli'));
        await tester.tap(find.widgetWithText(ListTile, 'Broccoli'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(english ? 'Save preferences' : 'Zapisz preferencje'),
        );
        await tester.pumpAndSettle();
        expect(service.saved!.toJson(), {
          'liked_product_ids': <String>[],
          'disliked_product_ids': ['broccoli'],
        });
        expect(
          find.text(
            english
                ? 'Ingredient preferences saved.'
                : 'Zapisano preferencje składników.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Standard keeps the same locked feature and existing Premium route',
    (tester) async {
      final service = _Preferences();
      await _open(tester, service, _Search(), premium: false, narrow: true);
      expect(service.loads, 0);
      expect(find.byType(TextField), findsNothing);
      await tester.ensureVisible(find.text('View Premium'));
      await tester.tap(find.text('View Premium'));
      await tester.pumpAndSettle();
      expect(find.text('Existing Premium screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('English error keeps unsaved changes and can be retried', (
    tester,
  ) async {
    final service = _Preferences()..failSave = true;
    await _open(tester, service, _Search(), narrow: true);
    await chooseBroccoli(tester);
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Not saved:'));
    expect(
      find.textContaining('The service is temporarily unavailable.'),
      findsOneWidget,
    );
    expect(service.saved, isNull);
    service.failSave = false;
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(service.saved!.liked.single.id, 'broccoli');
    expect(tester.takeException(), isNull);
  });
}
