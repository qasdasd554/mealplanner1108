import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/recipe_import_job.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/recipes/ai_add_recipe_screen.dart';
import 'package:smart_meal_planner/services/recipe_service.dart';

class _Auth extends AuthProvider {
  _Auth(this.country) : super(readToken: () async => null);
  final String country;
  int profileRefreshes = 0;
  @override
  User get currentUser => User(
    id: 'ai-test',
    email: 'ai@example.test',
    householdSize: 1,
    isPremium: true,
    countryCode: country,
    createdAt: DateTime.utc(2026),
  );
  @override
  Future<void> loadProfile() async {
    profileRefreshes++;
  }
}

class _Imports extends RecipeService {
  final polled = <String>[];
  final response = Completer<RecipeImportJob>();
  Completer<List<RecipeImportJob>>? restoring;
  @override
  Future<List<RecipeImportJob>> getRecentRecipeImportJobs() async =>
      restoring == null
          ? [const RecipeImportJob(id: 'active', status: 'processing')]
          : await restoring!.future;
  @override
  Future<RecipeImportJob> getRecipeImportJob(String id) async {
    polled.add(id);
    return response.future;
  }

  @override
  Future<RecipeImportJob> startRecipeImport({
    String? text,
    String? url,
    String? photoBase64,
  }) async => const RecipeImportJob(id: 'new-job', status: 'queued');
}

Widget _app(_Auth auth, _Imports service) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: Locale(auth.country == 'GB' ? 'en' : 'pl'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AiAddRecipeScreen(
          recipeService: service,
          initialText: 'Synthetic recipe',
        ),
      ),
    );

void main() {
  for (final country in ['PL', 'GB']) {
    testWidgets(
      '$country slow import polling stays single-flight and reaches ready state',
      (tester) async {
        final auth = _Auth(country);
        final service = _Imports();
        addTearDown(auth.dispose);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
        });
        await tester.pumpWidget(_app(auth, service));
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        expect(service.polled, ['active']);
        await tester.pump(const Duration(seconds: 12));
        expect(service.polled, ['active']);
        service.response.complete(
          const RecipeImportJob(
            id: 'active',
            status: 'completed',
            recipeId: 'recipe',
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(
          find.text(
            country == 'GB' ? 'Your recipe is ready' : 'Przepis jest gotowy',
          ),
          findsOneWidget,
        );
        expect(auth.profileRefreshes, 1);
        await tester.pump(const Duration(seconds: 12));
        expect(service.polled, ['active']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$country leaving an import with an outstanding poll does not update disposed UI',
      (tester) async {
        final auth = _Auth(country);
        final service = _Imports();
        addTearDown(auth.dispose);
        await tester.pumpWidget(_app(auth, service));
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpWidget(const SizedBox());
        service.response.complete(
          const RecipeImportJob(
            id: 'active',
            status: 'completed',
            recipeId: 'recipe',
          ),
        );
        await tester.pump();
        expect(auth.profileRefreshes, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$country late restore cannot replace the import just submitted',
      (tester) async {
        final auth = _Auth(country);
        final service =
            _Imports()..restoring = Completer<List<RecipeImportJob>>();
        addTearDown(auth.dispose);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
        });
        await tester.pumpWidget(_app(auth, service));
        await tester.pump();
        final strings = AppLocalizations.of(
          tester.element(find.byType(AiAddRecipeScreen)),
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, strings.aiRecipeRecognise),
        );
        await tester.pump();
        service.restoring!.complete([
          const RecipeImportJob(id: 'old-job', status: 'processing'),
        ]);
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        expect(service.polled, ['new-job']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
