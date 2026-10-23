import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/recipe_comment.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/services/recipe_comment_service.dart';
import 'package:smart_meal_planner/widgets/recipe_comments_section.dart';
import 'package:smart_meal_planner/widgets/report_block_menu.dart';

class _Service extends RecipeCommentService {
  bool fail = false;
  bool corruptPhoto = false;
  int submits = 0;
  Completer<RecipeComment>? pending;
  RecipeComment get comment => RecipeComment(
    id: 'comment',
    recipeId: 'r',
    userId: 'other',
    authorName: 'Original author',
    text: 'Oryginalna opinia autora',
    photoBase64: corruptPhoto ? 'this-is-not-base64!' : null,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
  @override
  Future<List<RecipeComment>> getComments(String id) async {
    if (fail) throw Exception('offline');
    return [comment];
  }

  @override
  Future<RecipeComment> addComment(
    String id, {
    String? text,
    String? photoBase64,
  }) async {
    submits++;
    if (fail) throw Exception('offline');
    return pending?.future ?? comment;
  }
}

Future<void> open(
  WidgetTester tester,
  _Service service, {
  bool english = true,
  bool narrow = false,
}) async {
  if (narrow) {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  final auth = AuthProvider(readToken: () async => null);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
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
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeCommentsSection(recipeId: 'r', service: service),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('GB comments localise controls and keep author text unchanged', (
    tester,
  ) async {
    await open(tester, _Service());
    expect(find.text('Comments and photos'), findsOneWidget);
    expect(find.text('Oryginalna opinia autora'), findsOneWidget);
    expect(find.text('5 min ago'), findsOneWidget);
    expect(find.byTooltip('Add photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('PL comments keep Polish controls', (tester) async {
    await open(tester, _Service(), english: false);
    expect(find.text('Komentarze i zdjęcia'), findsOneWidget);
    expect(find.byTooltip('Dodaj zdjęcie'), findsOneWidget);
  });
  testWidgets('bad comment photo cannot crash its recipe', (tester) async {
    await open(tester, _Service()..corruptPhoto = true);
    expect(find.text('Oryginalna opinia autora'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed submit retains text and allows retry without duplicate requests',
    (tester) async {
      final service = _Service()..fail = true;
      await open(tester, service);
      await tester.enterText(find.byType(TextField), 'Keep my text');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Keep my text'), findsOneWidget);
      expect(service.submits, 1);
      service.fail = false;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
      await tester.pumpAndSettle();
      expect(service.submits, 2);
      expect(find.text('Keep my text'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reporting fits narrow enlarged text and survives closing keyboard dialog',
    (tester) async {
      await open(tester, _Service(), narrow: true);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report content'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'My report details');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('report submits original API reason ID, never its translation', (
    tester,
  ) async {
    await open(tester, _Service());
    final context = tester.element(find.byType(RecipeCommentsSection));
    String? reason;
    final future = showReportDialog(
      context,
      onSubmit: (value, details) async {
        reason = value;
        return true;
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spam or advertising'));
    await tester.tap(find.widgetWithText(FilledButton, 'Report'));
    await tester.pumpAndSettle();
    await future;
    expect(reason, 'spam');
    expect(
      find.text('Thank you. Our team will review your report.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
