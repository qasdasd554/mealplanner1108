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
  final photo = find.byType(Image);
  if (photo.evaluate().isNotEmpty) {
    await tester.runAsync(() async {
      await precacheImage(
        tester.widget<Image>(photo.first).image,
        tester.element(photo.first),
      );
    });
    await tester.pumpAndSettle();
  }
  final originalSize = tester.view.physicalSize;
  // For contextual offers, capture the card up to the pricing section.
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
  String currency = 'GBP';
  int buys = 0;
  int restores = 0;
  String? purchasedPointsId;
  int catalogueQueries = 0;
  Future<bool>? pendingAvailability;
  Future<ProductDetailsResponse>? pendingCatalogue;
  Future<void>? pendingRestore;
  bool includePoints = false;
  bool includeSubscriptions = true;
  List<Future<bool>> pending = [];
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  @override
  Future<bool> isAvailable() => pendingAvailability ?? Future.value(available);
  @override
  Future<ProductDetailsResponse> queryCatalogue() async {
    catalogueQueries++;
    if (pendingCatalogue != null) return pendingCatalogue!;
    if (productsFail) throw StateError('Synthetic product query failure');
    return ProductDetailsResponse(
      productDetails: [
        if (includeSubscriptions) ...[
          fixtures.android(
            trial: 0,
            amount: currency == 'PLN' ? 24990000 : 5000000,
            currency: currency,
            priceLabel: currency == 'PLN' ? '24,99 zł' : null,
          ),
          fixtures.android(
            id: kYearlyProductId,
            trial: 0,
            amount: currency == 'PLN' ? 239990000 : 48000000,
            currency: currency,
            period: 'P1Y',
            priceLabel: currency == 'PLN' ? '239,99 zł' : null,
          ),
        ],
        if (includePoints)
          ProductDetails(
            id: kPoints10ProductId,
            title: '10 points',
            description: '',
            price: currency == 'PLN' ? '8,99 zł' : '£1.99',
            rawPrice: currency == 'PLN' ? 8.99 : 1.99,
            currencyCode: currency,
          ),
      ],
      notFoundIDs: [],
    );
  }

  @override
  Future<bool> hasSevenDayFreeTrial(ProductDetails product) =>
      pending.isEmpty ? Future.value(eligible) : pending.removeAt(0);
  @override
  Future<void> buy(ProductDetails product) async {
    buys++;
  }

  @override
  Future<void> buyPoints(ProductDetails product) async {
    purchasedPointsId = product.id;
  }

  @override
  Future<void> restorePurchases() async {
    restores++;
    await pendingRestore;
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
  PremiumOfferContext offerContext = PremiumOfferContext.recipe,
  bool fullscreen = false,
  bool settle = true,
}) async {
  tester.view.physicalSize =
      viewport ?? (narrow ? const Size(320, 740) : const Size(390, 844));
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  billing.currency = english ? 'GBP' : 'PLN';
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
  final screen = RepaintBoundary(
    key: _proofKey,
    child: PremiumScreen(
      billing: billing,
      client: api ?? _Api(),
      offerContext:
          generalOffer
              ? null
              : shoppingListLimit
              ? PremiumOfferContext.shoppingList
              : offerContext,
      shoppingListLimit: shoppingListLimit,
    ),
  );
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
        home: fullscreen ? null : screen,
        routes: fullscreen ? {'/': (_) => const SizedBox.expand()} : const {},
        onGenerateInitialRoutes:
            fullscreen
                ? (_) => [
                  MaterialPageRoute<void>(
                    builder: (_) => const SizedBox.expand(),
                  ),
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => screen,
                  ),
                ]
                : null,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
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
  testWidgets('a stalled catalogue can be retried from a recipe offer', (
    tester,
  ) async {
    final stalled = Completer<ProductDetailsResponse>();
    final billing = _Billing()..pendingCatalogue = stalled.future;
    await open(tester, billing, english: false, settle: false);
    final strings = AppLocalizations.of(
      tester.element(find.byType(PremiumScreen)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.ensureVisible(find.text(strings.premiumSeePlans));
    await tester.tap(find.text(strings.premiumSeePlans));
    await tester.pumpAndSettle();
    final retry = find.byKey(const ValueKey('premium-plans-retry'));
    expect(retry.hitTestable(), findsOneWidget);
    billing
      ..pendingCatalogue = null
      ..includePoints = true;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    await pricing(tester, strings.premiumMonthly);
    await tester.scrollUntilVisible(find.text('8,99 zł'), 250);
    expect(find.text('8,99 zł'), findsOneWidget);
    stalled.complete(
      ProductDetailsResponse(productDetails: [], notFoundIDs: []),
    );
    await tester.pumpAndSettle();
    expect(find.text('8,99 zł'), findsOneWidget);
    expect(billing.catalogueQueries, 2);
  });

  testWidgets('a stalled store connection can be retried from points', (
    tester,
  ) async {
    final stalled = Completer<bool>();
    final billing = _Billing()..pendingAvailability = stalled.future;
    await open(tester, billing, settle: false);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    final retry = find.byKey(const ValueKey('premium-points-retry'));
    await tester.scrollUntilVisible(retry, 250);
    expect(billing.catalogueQueries, 0);
    billing
      ..pendingAvailability = null
      ..includePoints = true
      ..includeSubscriptions = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('£1.99'), findsOneWidget);
    final strings = AppLocalizations.of(
      tester.element(find.byType(PremiumScreen)),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(
      find.text(strings.premiumSubscriptionPricesUnavailable),
      findsOneWidget,
    );
    stalled.complete(true);
    await tester.pumpAndSettle();
    expect(billing.catalogueQueries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Premium tab retries missing prices on foreground return', (
    tester,
  ) async {
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final stalled = Completer<ProductDetailsResponse>();
    final billing = _Billing()..pendingCatalogue = stalled.future;
    await open(
      tester,
      billing,
      generalOffer: true,
      english: false,
      settle: false,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    final retry = find.byKey(const ValueKey('premium-plans-retry'));
    expect(retry, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(billing.catalogueQueries, 1);

    billing
      ..pendingCatalogue = null
      ..includePoints = true;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await pricing(tester, 'Miesięcznie');
    expect(find.text('24,99 zł', findRichText: true), findsOneWidget);
    await tester.scrollUntilVisible(find.text('8,99 zł'), 250);
    expect(find.text('8,99 zł'), findsOneWidget);
    expect(billing.catalogueQueries, 2);
    stalled.complete(
      ProductDetailsResponse(productDetails: [], notFoundIDs: []),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stalled restore releases the button and allows retry', (
    tester,
  ) async {
    final stalled = Completer<void>();
    final billing = _Billing()..pendingRestore = stalled.future;
    await open(tester, billing, generalOffer: true);
    final strings = AppLocalizations.of(
      tester.element(find.byType(PremiumScreen)),
    );
    final restore = find.widgetWithText(
      TextButton,
      strings.premiumRestorePurchases,
    );
    await tester.scrollUntilVisible(restore, 250);
    await tester.pumpAndSettle();
    expect(restore.hitTestable(), findsOneWidget);
    await tester.tap(restore);
    await tester.pump();
    expect(tester.widget<TextButton>(restore).onPressed, isNull);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(restore).onPressed, isNotNull);
    billing.pendingRestore = null;
    await tester.tap(restore);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(billing.restores, 2);
    expect(find.text(strings.premiumRestoreEmpty), findsOneWidget);
    stalled.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final offer in PremiumOfferContext.values) {
    testWidgets('offer $offer opens live plan and point sections', (
      tester,
    ) async {
      final billing = _Billing()..includePoints = true;
      await open(
        tester,
        billing,
        offerContext: offer,
        english: false,
        branded: true,
        fullscreen: true,
        viewport: const Size(414, 980),
      );
      final strings = AppLocalizations.of(
        tester.element(find.byType(PremiumScreen)),
      );
      if (offer == PremiumOfferContext.recipe) {
        await capturePremium(
          tester,
          'premium-recipe-notice-pl',
          cropAtPricing: false,
        );
      }
      final seePlans = find.text(strings.premiumSeePlans);
      await tester.ensureVisible(seePlans);
      await tester.tap(seePlans);
      await tester.pumpAndSettle();
      expect(find.text(strings.premiumMonthly).hitTestable(), findsOneWidget);
      if (offer == PremiumOfferContext.recipe) {
        await capturePremium(
          tester,
          'premium-recipe-prices-pl',
          cropAtPricing: false,
        );
      }
      await tester.scrollUntilVisible(find.text('8,99 zł'), 210);
      expect(find.text('8,99 zł'), findsOneWidget);
      if (offer == PremiumOfferContext.recipe) {
        final buyPoints = find.widgetWithText(
          TextButton,
          strings.aiEditBuyPoints,
        );
        await tester.scrollUntilVisible(buyPoints, 210);
        await tester.tap(buyPoints);
        await tester.pump();
        expect(billing.purchasedPointsId, kPoints10ProductId);
      }
      expect(billing.catalogueQueries, 1);
      expect(tester.takeException(), isNull);
    });
  }
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
        for (final label in [
          strings.premiumBatchActionTitle,
          strings.premiumPointsTitle,
        ]) {
          final shortcut = find.text(label);
          if (shortcut.evaluate().isNotEmpty) {
            expect(tester.getTopLeft(shortcut).dy, greaterThan(844));
          }
        }
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
      final yearlyCard = tester.widget<Container>(
        find.byKey(const ValueKey('premium-yearly-card')),
      );
      final background = (yearlyCard.decoration! as BoxDecoration).color!;
      expect(
        (background.computeLuminance() + .05) / (textLuminance + .05),
        greaterThanOrEqualTo(4.5),
      );
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
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('premium-plans-retry')),
        250,
      );
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
    testWidgets('Premium uses a compact toolbar and an unobscured badge '
        '(${english ? 'GB' : 'PL'})', (tester) async {
      await open(
        tester,
        _Billing()..eligible = true,
        english: english,
        branded: true,
      );
      expect(
        tester.widget<SliverAppBar>(find.byType(SliverAppBar)).expandedHeight,
        isNull,
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
      await capturePremium(tester, 'premium-${english ? 'gb' : 'pl'}-390-100');
    });
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
