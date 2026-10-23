import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/l10n/app_localizations_en.dart';
import 'package:smart_meal_planner/l10n/app_localizations_pl.dart';
import 'package:smart_meal_planner/l10n/catalog_labels.dart';
import 'package:smart_meal_planner/models/recipe_import_job.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/recipes/ai_add_recipe_screen.dart';
import 'package:smart_meal_planner/screens/recipes/manual_add_recipe_screen.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';

class _Auth extends AuthProvider {
  final User user;

  _Auth(this.user) : super(readToken: () async => null);

  @override
  User get currentUser => user;
}

class _Imports extends RecipeService {
  final List<String?> submittedTexts = [];

  @override
  Future<List<RecipeImportJob>> getRecentRecipeImportJobs() async => [];

  @override
  Future<RecipeImportJob> startRecipeImport({
    String? text,
    String? url,
    String? photoBase64,
  }) async {
    submittedTexts.add(text);
    return const RecipeImportJob(id: 'local-test-job', status: 'queued');
  }
}

User _user(String country, int points) => User(
  id: 'test-user',
  email: 'local@example.test',
  countryCode: country,
  householdSize: 1,
  premiumPoints: points,
  createdAt: DateTime.utc(2026, 10, 16),
);

Widget _app(String country, Widget child) => MaterialApp(
  locale: country == 'GB' ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);

void main() {
  test('ingredient measure display labels preserve stored measure codes', () {
    const codes = ['opak', 'porcja', 'szt', 'lyzeczka', 'szklanka', 'g', 'ml'];
    expect(codes.map(AppLocalizationsPl().unitLabel), [
      'opak.',
      'porcja',
      'szt.',
      'łyżeczka',
      'szklanka',
      'g',
      'ml',
    ]);
    expect(codes.map(AppLocalizationsEnGb().unitLabel), [
      'pack',
      'serving',
      'pcs',
      'tsp',
      'cup',
      'g',
      'ml',
    ]);
    expect(codes, ['opak', 'porcja', 'szt', 'lyzeczka', 'szklanka', 'g', 'ml']);
  });

  for (final country in ['PL', 'GB']) {
    final english = country == 'GB';

    testWidgets('$country manual form keeps canonical API dropdown values', (
      tester,
    ) async {
      await tester.pumpWidget(_app(country, const ManualAddRecipeScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text(english ? 'Add a recipe manually' : 'Dodaj przepis ręcznie'),
        findsOneWidget,
      );
      final menus =
          tester
              .widgetList<DropdownButton<String>>(
                find.byType(DropdownButton<String>),
              )
              .toList();
      expect(menus[0].items!.map((item) => item.value), [
        'śniadanie',
        'obiad',
        'kolacja',
        'przekąska',
        'deser',
      ]);
      expect(menus[1].items!.map((item) => item.value), [
        'łatwy',
        'średni',
        'trudny',
      ]);
      expect(
        (menus[0].items![1].child as Text).data,
        english ? 'lunch' : 'obiad',
      );
      expect(
        (menus[1].items![0].child as Text).data,
        english ? 'easy' : 'łatwy',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$country typing and back confirmation preserve recipe name', (
      tester,
    ) async {
      await tester.pumpWidget(_app(country, const ManualAddRecipeScreen()));
      await tester.pumpAndSettle();
      final title = find.widgetWithText(
        TextFormField,
        english ? 'Recipe name' : 'Nazwa przepisu',
      );
      final description = find.widgetWithText(
        TextFormField,
        english ? 'Short description (optional)' : 'Krótki opis (opcjonalnie)',
      );
      await tester.enterText(title, 'My family lasagne');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      final editable = find.descendant(
        of: description,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.text(english ? 'Discard changes?' : 'Odrzucić zmiany?'),
        findsOneWidget,
      );
      await tester.tap(find.text(english ? 'Stay' : 'Zostań'));
      await tester.pumpAndSettle();
      expect(find.text('My family lasagne'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$country ingredient search opens translated empty state', (
      tester,
    ) async {
      await tester.pumpWidget(_app(country, const ManualAddRecipeScreen()));
      await tester.pumpAndSettle();
      final add = find.widgetWithText(TextButton, english ? 'Add' : 'Dodaj');
      await tester.scrollUntilVisible(
        add,
        200,
        scrollable:
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(
        find.text(english ? 'Choose an ingredient' : 'Wybierz składnik'),
        findsOneWidget,
      );
      expect(
        find.text(
          english
              ? 'Enter at least 2 characters to find an ingredient.'
              : 'Wpisz co najmniej 2 znaki, aby znaleźć składnik.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$country AI access still requires Premium or two points', (
      tester,
    ) async {
      final auth = _Auth(_user(country, 1));
      await auth.initialization;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: _app(country, AiAddRecipeScreen(recipeService: _Imports())),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(english ? 'Premium feature' : 'Funkcja Premium'),
        findsOneWidget,
      );
      expect(
        find.textContaining(english ? '2 premium points' : '2 punkty premium'),
        findsOneWidget,
      );
      expect(find.byType(TabBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    });

    testWidgets(
      '$country AI tabs keep text and submit exact unmodified input',
      (tester) async {
        final auth = _Auth(_user(country, 2));
        final imports = _Imports();
        await auth.initialization;
        await tester.pumpWidget(
          ChangeNotifierProvider<AuthProvider>.value(
            value: auth,
            child: _app(country, AiAddRecipeScreen(recipeService: imports)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TabBar), findsOneWidget);
        final input =
            find
                .descendant(
                  of: find.byType(TabBarView),
                  matching: find.byType(TextField),
                )
                .first;
        await tester.enterText(input, '  Crêpes with 200 ml milk  ');
        await tester.tap(
          find.widgetWithText(Tab, english ? 'Photo' : 'Zdjęcie'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            english ? 'Tap to add a photo' : 'Dotknij, aby dodać zdjęcie',
          ),
          findsOneWidget,
        );
        final disabled = tester.widget<ElevatedButton>(
          find
              .widgetWithText(
                ElevatedButton,
                english ? 'Recognise recipe' : 'Rozpoznaj przepis',
              )
              .last,
        );
        expect(disabled.onPressed, isNull);
        await tester.tap(
          find.widgetWithText(Tab, english ? 'Paste text' : 'Wklej tekst'),
        );
        await tester.pumpAndSettle();
        expect(find.text('  Crêpes with 200 ml milk  '), findsOneWidget);
        await tester.tap(
          find
              .widgetWithText(
                ElevatedButton,
                english ? 'Recognise recipe' : 'Rozpoznaj przepis',
              )
              .first,
        );
        await tester.pump();
        expect(imports.submittedTexts, ['Crêpes with 200 ml milk']);
        expect(
          find.text(
            english
                ? 'Your recipe is being prepared'
                : 'Twój przepis jest przygotowywany',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
      },
    );

    testWidgets('$country AI shared links stay intact on the link tab', (
      tester,
    ) async {
      final auth = _Auth(_user(country, 2));
      await auth.initialization;
      const link = 'https://example.test/recipe?title=Cr%C3%AApes';
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: _app(
            country,
            AiAddRecipeScreen(recipeService: _Imports(), initialUrl: link),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(english ? 'Paste a recipe link' : 'Wklej link do przepisu'),
        findsOneWidget,
      );
      expect(find.text(link), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    });
  }
}
