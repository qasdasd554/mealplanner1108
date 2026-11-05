import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// The inherited BillingService field is initialized even with mocked methods.
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_meal_planner/l10n/app_localizations.dart';
import 'package:smart_meal_planner/models/premium_offer.dart';
import 'package:smart_meal_planner/providers/auth_provider.dart';
import 'package:smart_meal_planner/screens/profile/premium_screen.dart';
import 'package:smart_meal_planner/services/api_client.dart';
import 'package:smart_meal_planner/services/billing_service.dart';
import 'package:smart_meal_planner/theme/app_theme.dart';
import '../../helpers/product_form_render.dart';
import '../../utils/subscription_presentation_test.dart' as fixtures;

const _proofKey = ValueKey('premium-responsive-proof');

class _Store extends InAppPurchasePlatform {}

Future<void> capturePremium(
  WidgetTester tester,
  String name, {
  bool cropAtPricing = true,
}) async {
  if (!const bool.fromEnvironment('UK_WRITE_UI_PROOF')) return;
  final originalSize = tester.view.physicalSize;
  // Capture only the header/context card. Raw RichText in the unrelated price
  // section uses the engine's square test font, not a production font.
  final monthly =
      find.text('Monthly').evaluate().isNotEmpty
          ? find.text('Monthly')
          : find.text('Miesięcznie');
  if (cropAtPricing && monthly.evaluate().isNotEmpty) {
    final height = tester.getTopLeft(monthly).dy - 24;
    if (height > 0 && height < originalSize.height) {
      tester.view.physicalSize = Size(originalSize.width, height);
      await tester.pumpAndSettle();
    }
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_proofKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../docs/uk-stage12/evidence/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
  tester.view.physicalSize = originalSize;
  await tester.pumpAndSettle();
}

class _Billing extends BillingService {
  bool eligible = false;
  bool available = true;
  bool productsFail = false;
  int buys = 0;
  int restores = 0;
  List<Future<bool>> pending = [];
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProducts() async {
    if (productsFail) throw StateError('Synthetic product query failure');
    return ProductDetailsResponse(
      productDetails: [
        fixtures.android(trial: 0, amount: 5000000),
        fixtures.android(
          id: kYearlyProductId,
          trial: 0,
          amount: 48000000,
          period: 'P1Y',
        ),
      ],
      notFoundIDs: [],
    );
  }

  @override
  Future<ProductDetailsResponse> queryPointsProducts() async =>
      ProductDetailsResponse(productDetails: [], notFoundIDs: []);
  @override
  Future<bool> hasSevenDayFreeTrial(ProductDetails product) =>
      pending.isEmpty ? Future.value(eligible) : pending.removeAt(0);
  @override
  Future<void> buy(ProductDetails product) async {
    buys++;
  }

  @override
  Future<void> restorePurchases() async {
    restores++;
  }
}

class _Api implements ApiClient {
  Completer<dynamic>? campaigns;
  @override
  Future<dynamic> get(String path, {Duration? timeout}) async =>
      campaigns == null ? [] : campaigns!.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> open(
  WidgetTester tester,
  _Billing billing, {
  bool english = true,
  bool narrow = false,
  Size? viewport,
  double? textScale,
  bool branded = false,
  bool dark = false,
  _Api? api,
  bool shoppingListLimit = false,
  bool generalOffer = false,
}) async {
  tester.view.physicalSize =
      viewport ?? (narrow ? const Size(320, 740) : const Size(390, 844));
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final auth = AuthProvider(readToken: () async => null);
  addTearDown(auth.dispose);
  AppTheme.setDark(dark);
  addTearDown(() => AppTheme.setDark(false));
  final baseTheme = branded ? productFormTheme(dark) : null;
  final buttonStyle = baseTheme?.elevatedButtonTheme.style;
  final theme =
      const bool.fromEnvironment('UK_WRITE_UI_PROOF') && baseTheme != null
          ? baseTheme.copyWith(
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: (buttonStyle ?? const ButtonStyle()).copyWith(
                textStyle: WidgetStateProperty.resolveWith(
                  (states) => (buttonStyle?.textStyle?.resolve(states) ??
                          const TextStyle())
                      .copyWith(fontFamily: 'UKStage8Proof'),
                ),
              ),
            ),
          )
          : baseTheme;
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        theme: theme,
        locale: english ? const Locale('en', 'GB') : const Locale('pl', 'PL'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale ?? (narrow ? 1.5 : 1)),
              ),
              child: child!,
            ),
        home: RepaintBoundary(
          key: _proofKey,
          child: PremiumScreen(
            billing: billing,
            client: api ?? _Api(),
            offerContext:
                generalOffer
                    ? null
                    : shoppingListLimit
                    ? PremiumOfferContext.shoppingList
                    : PremiumOfferContext.recipe,
            shoppingListLimit: shoppingListLimit,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pricing(WidgetTester tester, String monthly) async {
  await tester.scrollUntilVisible(find.text(monthly), 450, maxScrolls: 20);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    InAppPurchasePlatform.instance = _Store();
    BillingService();
    debugDefaultTargetPlatformOverride = null;
    await loadProductFormFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final english in [false, true]) {
    testWidgets(
      'general offer shows local plans before shortcuts (${english ? "GB" : "PL"})',
      (tester) async {
        await open(
          tester,
          _Billing()..eligible = true,
          english: english,
          generalOffer: true,
          branded: true,
        );
        final strings = AppLocalizations.of(
          tester.element(find.byType(PremiumScreen)),
        );
        final monthly = find.text(strings.premiumMonthly);
        // A profile entry used to require scrolling past seven shortcut cards
        // and six descriptions before the first store price appeared.
        expect(monthly, findsOneWidget);
        expect(tester.getTopLeft(monthly).dy, lessThan(844));
        expect(find.text(strings.premiumBatchActionTitle), findsNothing);
        expect(find.text(strings.premiumPointsTitle), findsNothing);
        expect(find.text(strings.premiumTryFree), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capturePremium(
          tester,
          'premium-conversion-${english ? "gb" : "pl"}-general',
          cropAtPricing: false,
        );
        await pricing(tester, strings.premiumMonthly);
        await capturePremium(
          tester,
          'premium-conversion-${english ? "gb" : "pl"}-plans',
          cropAtPricing: false,
        );
      },
    );
    for (final productsFail in [false, true]) {
      testWidgets('restore works independently of product prices '
          '(${english ? "GB" : "PL"}, query failure=$productsFail)', (
        tester,
      ) async {
        final billing =
            _Billing()
              ..available = productsFail
              ..productsFail = productsFail;
        await open(tester, billing, english: english, generalOffer: true);
        final strings = AppLocalizations.of(
          tester.element(find.byType(PremiumScreen)),
        );
        final restore = find.text(strings.premiumRestorePurchases);
        await tester.scrollUntilVisible(restore, 250);
        await tester.pumpAndSettle();
        await tester.tap(restore);
        await tester.pump();
        expect(billing.restores, 1);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(find.text(strings.premiumRestoreEmpty), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    for (final trial in [false, true]) {
      testWidgets(
        'weekly list limit offer ${english ? "GB" : "PL"} trial=$trial fits narrow screen',
        (tester) async {
          final billing = _Billing()..eligible = trial;
          await open(
            tester,
            billing,
            english: english,
            narrow: true,
            shoppingListLimit: true,
          );
          final title =
              english
                  ? 'More shopping? Go unlimited with Premium'
                  : 'Kolejne zakupy? Z Premium bez limitu';
          await tester.scrollUntilVisible(find.text(title), 300);
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
          final back = find.text(
            english ? 'Back to my shopping list' : 'Wróć do mojej listy',
          );
          await tester.scrollUntilVisible(back, 250);
          await tester.pumpAndSettle();
          expect(back, findsOneWidget);
          if (!trial)
            expect(
              find.text(english ? 'Explore Premium' : 'Zobacz Premium'),
              findsOneWidget,
            );
          expect(billing.buys, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'GB offer and real prices are English without an unverified trial',
    (tester) async {
      final billing = _Billing();
      await open(tester, billing);
      expect(find.text('Turn an idea into a recipe'), findsOneWidget);
      expect(find.text('7 DAYS FREE*'), findsNothing);
      await pricing(tester, 'Monthly');
      expect(find.text('7 days free'), findsNothing);
      expect(find.text('Try for free'), findsNothing);
      expect(find.text('£5.00', findRichText: true), findsOneWidget);
      expect(
        find.textContaining('Renews automatically each month'),
        findsNothing,
      );
      expect(find.text('Save 20%'), findsOneWidget);
      final yearlyLabel = tester.widget<Text>(find.text('Yearly'));
      final textLuminance = yearlyLabel.style!.color!.computeLuminance();
      for (final background in [
        const Color(0xFFF5C24D),
        const Color(0xFFE0A62E),
      ]) {
        expect(
          (background.computeLuminance() + .05) / (textLuminance + .05),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(find.text('Save 17%'), findsNothing);
      expect(billing.buys, 0);
      expect(tester.takeException(), isNull);
    },
  );
  for (final english in [true, false]) {
    testWidgets(
      'verified trial and renewal copy are localised (${english ? 'GB' : 'PL'})',
      (tester) async {
        await open(tester, _Billing()..eligible = true, english: english);
        expect(
          find.text(english ? '7 DAYS FREE*' : '7 DNI ZA 0 ZŁ*'),
          findsOneWidget,
        );
        await pricing(tester, english ? 'Monthly' : 'Miesięcznie');
        expect(
          find.text(english ? '7 days free' : '7 dni za darmo'),
          findsOneWidget,
        );
        expect(
          find.text(english ? 'Try for free' : 'Wypróbuj za 0 zł'),
          findsOneWidget,
        );
        final button = find.text(english ? 'Try for free' : 'Wypróbuj za 0 zł');
        final terms = find.textContaining(
          english
              ? 'Renews automatically each month'
              : 'Odnawia się automatycznie co miesiąc',
        );
        expect(terms, findsOneWidget);
        expect(
          tester.getTopLeft(terms).dy - tester.getBottomLeft(button).dy,
          inInclusiveRange(0, 44),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('late eligibility from an obsolete offer cannot show a trial', (
    tester,
  ) async {
    final old = Completer<bool>(), campaigns = Completer<dynamic>();
    final billing = _Billing()..pending = [old.future, Future.value(false)];
    await open(tester, billing, api: _Api()..campaigns = campaigns);
    campaigns.complete([]);
    await tester.pumpAndSettle();
    old.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('7 DAYS FREE*'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('closing before the native check ends is safe', (tester) async {
    final pending = Completer<bool>();
    await open(tester, _Billing()..pending = [pending.future, pending.future]);
    await tester.pumpWidget(const SizedBox());
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'unavailable store stays recoverable and does not promise a trial',
    (tester) async {
      await open(tester, _Billing()..available = false);
      await pricing(tester, 'Try again');
      expect(find.text('Try for free'), findsNothing);
      expect(
        find.text(
          'Purchases are unavailable on this device. Please check your Google Play account.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final english in [true, false]) {
    testWidgets(
      'Premium fits a narrow enlarged-text screen (${english ? 'GB' : 'PL'})',
      (tester) async {
        await open(
          tester,
          _Billing()..eligible = true,
          english: english,
          narrow: true,
        );
        expect(tester.takeException(), isNull);
        await pricing(tester, english ? 'Monthly' : 'Miesięcznie');
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final english in [true, false]) {
    testWidgets(
      'ordinary Premium keeps the original header and an unobscured badge '
      '(${english ? 'GB' : 'PL'})',
      (tester) async {
        await open(
          tester,
          _Billing()..eligible = true,
          english: english,
          branded: true,
        );
        expect(
          tester.widget<SliverAppBar>(find.byType(SliverAppBar)).expandedHeight,
          250,
        );
        final title = tester.getRect(
          find.byKey(const ValueKey('premium-context-title')),
        );
        final badge = tester.getRect(
          find.byKey(const ValueKey('premium-context-trial-badge')),
        );
        expect(badge.bottom <= title.top || badge.top >= title.bottom, isTrue);
        expect(badge.right, lessThanOrEqualTo(390));
        if (const bool.fromEnvironment('UK_WRITE_UI_PROOF')) {
          // Arial proof reflects real glyph widths; Ahem deliberately uses
          // oversized square glyphs and can correctly trigger the fallback.
          expect(badge.bottom, lessThanOrEqualTo(title.top));
        }
        expect(tester.takeException(), isNull);
        await capturePremium(
          tester,
          'premium-${english ? 'gb' : 'pl'}-390-100',
        );
      },
    );
    for (final dark in [false, true]) {
      testWidgets('Premium reflows enlarged text without clipping '
          '(${english ? 'GB' : 'PL'}, ${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        await open(
          tester,
          _Billing()..eligible = true,
          english: english,
          narrow: true,
          textScale: 2,
          branded: true,
          dark: dark,
        );
        final title = tester.getRect(
          find.byKey(const ValueKey('premium-context-title')),
        );
        final badge = tester.getRect(
          find.byKey(const ValueKey('premium-context-trial-badge')),
        );
        expect(badge.top, greaterThanOrEqualTo(title.bottom));
        expect(badge.left, greaterThanOrEqualTo(0));
        expect(badge.right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
        final name =
            'premium-${english ? 'gb' : 'pl'}-320-200-'
            '${dark ? 'dark' : 'light'}';
        await capturePremium(tester, '$name-top');
        await pricing(tester, english ? 'Monthly' : 'Miesięcznie');
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('Premium stays scrollable on a short landscape screen '
        '(${english ? 'GB' : 'PL'})', (tester) async {
      await open(
        tester,
        _Billing()..eligible = true,
        english: english,
        viewport: const Size(740, 320),
        textScale: 1.5,
        branded: true,
      );
      expect(tester.takeException(), isNull);
      await pricing(tester, english ? 'Monthly' : 'Miesięcznie');
      expect(tester.takeException(), isNull);
    });
  }
}
