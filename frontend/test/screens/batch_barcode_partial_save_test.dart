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

class _Camera extends MobileScannerPlatform {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<void> updateScanWindow(Rect? rect) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.off,
        size: Size(640, 480),
      );
}

class _Auth extends AuthProvider {
  _Auth(this.country) : super(readToken: () async => null);
  final String country;
  int refreshes = 0;
  @override
  User get currentUser => User(
    id: 'batch-user',
    email: 'batch@example.test',
    householdSize: 1,
    isPremium: true,
    countryCode: country,
    createdAt: DateTime.utc(2026),
  );
  @override
  Future<void> loadProfile() async {
    refreshes++;
  }
}

class _Diary extends FoodLogProvider {
  @override
  Future<void> fetchLogsForDate(DateTime date) async {}
}

class _Lookup extends BarcodeLookupService {
  @override
  Future<BarcodeLookupResult> lookup(String code) async =>
      const BarcodeLookupResult(
        found: true,
        name: 'Synthetic milk',
        unit: 'ml',
        servingQuantity: 250,
        kcalPer100: 60,
        proteinPer100: 3,
        fatPer100: 2,
        carbsPer100: 5,
        source: 'open_food_facts_direct',
      );
}

class _Api extends ApiClient {
  _Api({required this.lostReply}) : super.forTesting(httpClient: http.Client());
  final bool lostReply;
  final Map<String, Map<String, dynamic>> entries = {};
  int catalogueWrites = 0;
  int diaryAttempts = 0;
  int diaryWrites = 0;
  Map<String, dynamic>? saved;
  @override
  Future<dynamic> post(String path, {dynamic body, Duration? timeout}) async {
    if (path == '/products/submit') {
      catalogueWrites++;
      return {'points_awarded': 1};
    }
    if (path == '/food-log/') {
      diaryAttempts++;
      if (diaryAttempts == 1 && !lostReply) {
        throw ApiException(503, 'Synthetic failure before diary save');
      }
      final payload = Map<String, dynamic>.from(body as Map);
      final key =
          payload['client_entry_id'] as String? ?? 'unkeyed-$diaryAttempts';
      if (entries.containsKey(key)) return entries[key];
      diaryWrites++;
      saved = payload;
      entries[key] = payload;
      if (diaryAttempts == 1 && lostReply) {
        throw ApiException(503, 'Synthetic lost reply after diary commit');
      }
      return saved;
    }
    throw StateError('Unexpected path $path');
  }
}

class _Pantry extends PantryService {
  int writes = 0;
  @override
  Future<PantryItem> addFromBarcode(
    String barcode, {
    required double quantity,
    required String unit,
    bool batch = false,
    BarcodeLookupResult? lookupResult,
  }) async {
    expect(quantity, 1);
    expect(unit, 'opak');
    expect(lookupResult?.servingQuantity, 250);
    writes++;
    return PantryItem(
      id: 'pantry',
      product: Product.fromJson({
        'id': 'milk',
        'name': 'Synthetic milk',
        'unit': 'opak',
      }),
    );
  }
}

void main() {
  for (final country in ['PL', 'GB']) {
    for (final lostReply in [false, true]) {
      testWidgets(
        '$country lostReply=$lostReply partial batch retry preserves successful destinations and whole-pack macros',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final original = MobileScannerPlatform.instance;
          MobileScannerPlatform.instance = _Camera();
          MobileScannerController.resetPlatformSessionOwner();
          final auth = _Auth(country);
          final diary = _Diary();
          final api = _Api(lostReply: lostReply);
          final pantry = _Pantry();
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            auth.dispose();
            diary.dispose();
            MobileScannerPlatform.instance = original;
            MobileScannerController.resetPlatformSessionOwner();
          });
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>.value(value: auth),
                ChangeNotifierProvider<FoodLogProvider>.value(value: diary),
              ],
              child: MaterialApp(
                locale: Locale(country == 'GB' ? 'en' : 'pl'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: BatchBarcodeScannerScreen(
                  lookupService: _Lookup(),
                  client: api,
                  pantryService: pantry,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.keyboard));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '5901234123457');
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(FilledButton),
            ),
          );
          await tester.pumpAndSettle();
          for (var index = 0; index < 3; index++) {
            await tester.tap(find.byType(FilterChip).at(index));
            await tester.pump();
          }
          final strings = AppLocalizations.of(
            tester.element(find.byType(BatchBarcodeScannerScreen)),
          );
          await tester.tap(find.text(strings.scanAddAllCount(1)));
          await tester.pumpAndSettle();
          expect(api.catalogueWrites, 1);
          expect(pantry.writes, 1);
          expect(api.diaryWrites, lostReply ? 1 : 0);
          expect(
            auth.refreshes,
            1,
            reason:
                'The catalogue reward succeeded even though the diary failed',
          );
          await tester.tap(find.byIcon(Icons.refresh));
          await tester.pumpAndSettle();
          await tester.tap(find.text(strings.scanAddAllCount(1)));
          await tester.pumpAndSettle();
          expect(api.catalogueWrites, 1);
          expect(pantry.writes, 1);
          expect(api.diaryAttempts, 2);
          expect(api.diaryWrites, 1);
          expect(
            api.saved?['client_entry_id'],
            matches(
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
              ),
            ),
          );
          expect(api.saved?['calories'], 150);
          expect(api.saved?['protein'], 7.5);
          expect(api.saved?['fat'], 5);
          expect(api.saved?['carbs'], 12.5);
          expect(api.saved?['amount_value'], 1);
          expect(api.saved?['amount_unit'], 'opak');
          expect(api.saved?['portion_size'], 250);
          expect(api.saved?['portion_unit'], 'ml');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
