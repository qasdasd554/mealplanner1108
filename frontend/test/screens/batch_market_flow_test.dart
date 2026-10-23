import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/barcode_lookup_result.dart';
import 'package:smart_meal_planner/models/product.dart';
import 'package:smart_meal_planner/models/user.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/providers/food_log_provider.dart';
import 'package:smart_meal_planner/screens/batch_barcode_scanner_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/barcode_lookup_service.dart';
import 'package:smart_meal_planner/services/pantry_service.dart';

class _Auth extends AuthProvider {
  final bool premium;
  int reloads = 0;
  _Auth({this.premium = true}) : super(readToken: () async => null);
  @override
  User get currentUser => User(
    id: 'user',
    email: 'local@example.test',
    countryCode: 'GB',
    householdSize: 1,
    isPremium: premium,
    createdAt: DateTime.utc(2026),
  );
  @override
  Future<void> loadProfile() async {
    reloads++;
  }
}

class _Logs extends FoodLogProvider {
  int reloads = 0;
  @override
  Future<void> fetchLogsForDate(DateTime date) async {
    reloads++;
  }
}

class _Camera extends MobileScannerController {
  _Camera() : super(autoStart: false);
  @override
  Future<void> start({
    CameraFacing? cameraDirection,
    CameraLensType? cameraLensType,
  }) async {}
  @override
  Future<void> stop() async {}
}

class _Lookup extends BarcodeLookupService {
  final double? size;
  final double kcal;
  _Lookup({this.size = 500, this.kcal = 100});
  @override
  Future<BarcodeLookupResult> lookup(String code) async => BarcodeLookupResult(
    found: true,
    name: 'Milk $code',
    source: 'open_food_facts',
    unit: 'ml',
    barcode: code,
    servingQuantity: size,
    kcalPer100: kcal,
    proteinPer100: 5,
    fatPer100: 2,
    carbsPer100: 8,
  );
}

class _Api extends ApiClient {
  final posts = <({String path, Map<String, dynamic> body})>[];
  _Api() : super.forTesting(httpClient: http.Client());
  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    posts.add((path: path, body: Map<String, dynamic>.from(body as Map)));
    return path == '/products/submit' ? {'points_awarded': 1} : body;
  }
}

class _Pantry extends PantryService {
  final saves = <({String code, double quantity, String unit, bool batch})>[];
  @override
  Future<PantryItem> addFromBarcode(
    String barcode, {
    required double quantity,
    required String unit,
    bool batch = false,
    BarcodeLookupResult? lookupResult,
  }) async {
    saves.add((code: barcode, quantity: quantity, unit: unit, batch: batch));
    return PantryItem(
      id: barcode,
      product: Product(
        id: barcode,
        name: 'Milk',
        unit: 'ml',
        defaultQuantity: 100,
        nutritionPer100: NutritionInfo.fromJson(<String, dynamic>{}),
      ),
    );
  }
}

Future<(_Api, _Pantry)> _open(
  WidgetTester tester, {
  bool premium = true,
  double? size = 500,
  double kcal = 100,
}) async {
  final auth = _Auth(premium: premium),
      logs = _Logs(),
      api = _Api(),
      pantry = _Pantry();
  addTearDown(auth.dispose);
  addTearDown(logs.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<FoodLogProvider>.value(value: logs),
      ],
      child: MaterialApp(
        locale: const Locale('en', 'GB'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: BatchBarcodeScannerScreen(
          controller: _Camera(),
          lookupService: _Lookup(size: size, kcal: kcal),
          client: api,
          pantryService: pantry,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (api, pantry);
}

Future<void> _enter(WidgetTester tester, String code) async {
  await tester.tap(find.byTooltip('Enter code manually'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.widgetWithText(FilledButton, 'Add'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('free GB users see English Premium preview without a camera', (
    tester,
  ) async {
    await _open(tester, premium: false);
    expect(find.text('Premium feature preview'), findsOneWidget);
    expect(find.byType(MobileScanner), findsNothing);
    expect(find.text('Pantry'), findsOneWidget);
    expect(find.text('Food diary'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'two scans use one multi-destination choice and retain pack nutrition',
    (tester) async {
      final (api, pantry) = await _open(tester);
      await _enter(tester, '5901234123457');
      await _enter(tester, '12345670');
      expect(find.text('Ready to add with the batch'), findsNWidgets(2));
      expect(api.posts, isEmpty);
      expect(pantry.saves, isEmpty);
      await tester.tap(find.widgetWithText(FilterChip, 'Pantry'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Catalogue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Food diary'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add all (2)'));
      await tester.pumpAndSettle();
      expect(
        api.posts.where((p) => p.path == '/products/submit'),
        hasLength(2),
      );
      final diary = api.posts.where((p) => p.path == '/food-log/').toList();
      expect(diary, hasLength(2));
      for (final post in diary) {
        expect(post.body['amount_unit'], 'opak');
        expect(post.body['amount_value'], 1);
        expect(post.body['portion_size'], 500);
        expect(post.body['portion_unit'], 'ml');
        expect(post.body['calories'], 500);
        expect(post.body['protein'], 25);
        expect(post.body['meal_type'], 'Przekąska');
      }
      expect(pantry.saves, hasLength(2));
      expect(
        pantry.saves.every(
          (s) => s.unit == 'opak' && s.quantity == 1 && s.batch,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'missing pack size never silently adds one gram or an invented pack',
    (tester) async {
      final (api, pantry) = await _open(tester, size: null);
      await _enter(tester, '5901234123457');
      expect(find.textContaining('whole-pack size is missing'), findsOneWidget);
      expect(api.posts, isEmpty);
      expect(pantry.saves, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('invalid macro from lookup cannot crash the partial batch item', (
    tester,
  ) async {
    await _open(tester, kcal: double.nan);
    await _enter(tester, '5901234123457');
    expect(
      find.textContaining('calories or macros are missing'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
