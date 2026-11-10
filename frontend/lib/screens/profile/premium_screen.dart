import 'package:flutter/material.dart';

import '../../l10n/market_locale.dart';

import 'package:flutter/foundation.dart';

import 'dart:io' show Platform;

import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:async';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/billing_service.dart';
import '../../services/api_client.dart';
import '../../models/premium_offer.dart';
import '../../utils/error_utils.dart';
import '../../utils/subscription_presentation.dart';
import '../../widgets/campaign_icon.dart';
import '../../widgets/app_document_links.dart';
import '../recipes/recipes_screen.dart';
import '../recipes/ai_add_recipe_screen.dart';
import '../recipes/ingredient_match_select_screen.dart';
import '../recipes/pantry_screen.dart';
import '../batch_barcode_scanner_screen.dart';
import '../meal_plan/weekly_plan_automation_screen.dart';

/// Ekran prezentacji subskrypcji Premium — lista korzyści + przyciski
/// zakupu, w pełni podłączone pod Google Play Billing. Backend (nie ta
/// aplikacja) ostatecznie decyduje, czy nadać dostęp premium — dopiero
/// PO zweryfikowaniu tokenu zakupu bezpośrednio u Google.
class PremiumScreen extends StatefulWidget {
  final bool popAfterSuccess;
  final PremiumOfferContext? offerContext;
  final bool shoppingListLimit;
  final BillingService? billing;
  final ApiClient? client;

  const PremiumScreen({
    super.key,
    this.popAfterSuccess = true,
    this.offerContext,
    this.shoppingListLimit = false,
    this.billing,
    this.client,
  });

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  static const _storeTimeout = Duration(seconds: 8);
  late final BillingService _billing;
  late final ApiClient _api;
  late final AppLifecycleListener _storeLifecycle;
  bool _monthlyHasSevenDayTrial = false;
  int _offerGeneration = 0;
  final GlobalKey _pricingSectionKey = GlobalKey();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _isLoadingCatalogue = false;
  Map<String, ProductDetails> _products = {};
  List<ProductDetails> _allSubscriptionProducts = [];
  Map<String, Map<String, dynamic>> _campaignsFromBackend = {};
  Map<String, Map<String, dynamic>> _activeOffers = {};
  String? _productsError;

  Map<String, ProductDetails> _pointsProducts = {};

  // Podczas przetwarzania zakupu blokujemy przyciski i pokazujemy
  // spinner — zakup przechodzi przez kilka asynchronicznych kroków
  // (Google -> backend -> potwierdzenie), więc to może potrwać kilka
  // sekund.
  bool _isProcessingPurchase = false;
  bool _isRestoring = false;
  final Set<String> _verifyingPurchases = {};
  final Set<String> _verifiedPurchases = {};
  int _restoreGeneration = 0;
  bool _restoreReceivedPurchase = false;

  IconData get _contextIcon => switch (widget.offerContext!) {
    PremiumOfferContext.recipe => Icons.menu_book_rounded,
    PremiumOfferContext.mealPlan => Icons.calendar_month_rounded,
    PremiumOfferContext.barcodeScanner => Icons.qr_code_scanner_rounded,
    PremiumOfferContext.shoppingList => Icons.shopping_cart_rounded,
    PremiumOfferContext.pantry => Icons.kitchen_rounded,
    PremiumOfferContext.journal => Icons.insights_rounded,
  };

  ({double width, double height, double minWidth}) _premiumTextMetrics(
    BuildContext context,
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: maxWidth.clamp(1.0, double.infinity).toDouble());
    final result = (
      width: painter.width,
      height: painter.height,
      minWidth: painter.minIntrinsicWidth,
    );
    painter.dispose();
    return result;
  }

  Widget _buildOfferIntro(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showPhoto =
            constraints.maxWidth >= 340 &&
            MediaQuery.textScalerOf(context).scale(16) <= 20;
        final dark = theme.brightness == Brightness.dark;
        final ink = dark ? const Color(0xFFF2EAFE) : const Color(0xFF302249);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF332748) : const Color(0xFFF0E9FD),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings.premiumHeroTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      context.strings.premiumHeroDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(color: ink),
                    ),
                  ],
                ),
              ),
              if (showPhoto) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/recipe_photos/new-63-roast-chicken-with-peaches-and-red-onion.jpg',
                    width: 92,
                    height: 112,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildContextualOfferCard(BuildContext context) {
    final baseCopy = PremiumOfferCopy.forContext(
      widget.offerContext!,
      strings: context.strings,
    );
    final copy =
        widget.shoppingListLimit
            ? PremiumOfferCopy(
              eyebrow: baseCopy.eyebrow,
              title: context.strings.shoppingLimitTitle,
              description: context.strings.shoppingLimitDescription,
              benefits: [context.strings.premiumContextShoppingBenefitLists],
            )
            : baseCopy;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final badgeText =
              _monthlyHasSevenDayTrial
                  ? context.strings.premiumTrialBadge(7)
                  : 'Premium';
          final badgeWidth =
              _premiumTextMetrics(
                context,
                badgeText,
                const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ).width +
              20;
          final titleMinWidth =
              _premiumTextMetrics(
                context,
                copy.eyebrow,
                const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ).minWidth;
          final stackBadge =
              constraints.maxWidth < 36 + 12 + titleMinWidth + badgeWidth;
          final badge = Container(
            key: const ValueKey('premium-context-trial-badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryTintColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _monthlyHasSevenDayTrial
                  ? context.strings.premiumTrialBadge(7)
                  : 'Premium',
              style: TextStyle(
                color: AppTheme.actionPrimaryColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryTintColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      _contextIcon,
                      color: AppTheme.actionPrimaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      copy.eyebrow,
                      style: TextStyle(
                        color: AppTheme.actionPrimaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (!stackBadge) badge,
                ],
              ),
              const SizedBox(height: 14),
              Text(
                copy.title,
                key: const ValueKey('premium-context-title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              if (stackBadge) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: badge),
              ],
              const SizedBox(height: 8),
              Text(
                copy.description,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ...copy.benefits.map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check,
                        size: 18,
                        color: AppTheme.actionPrimaryColor,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          benefit,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    final pricingContext = _pricingSectionKey.currentContext;
                    if (pricingContext != null) {
                      Scrollable.ensureVisible(
                        pricingContext,
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        alignment: 0.18,
                      );
                    }
                  },
                  child: Text(
                    _monthlyHasSevenDayTrial
                        ? context.strings.premiumCheckTrial
                        : widget.shoppingListLimit
                        ? context.strings.shoppingLimitSeePremium
                        : context.strings.premiumSeePlans,
                  ),
                ),
              ),
              if (_monthlyHasSevenDayTrial) ...[
                const SizedBox(height: 8),
                Text(
                  context.strings.premiumTrialEligibilityFootnote(
                    Platform.isIOS ? 'App Store' : 'Google Play',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed:
                      () =>
                          widget.shoppingListLimit
                              ? Navigator.of(context).pop('shopping-list')
                              : Navigator.of(context).maybePop(),
                  child: Text(
                    widget.shoppingListLimit
                        ? context.strings.shoppingLimitBack
                        : context.strings.premiumNotNow,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _billing = widget.billing ?? BillingService();
    _api = widget.client ?? ApiClient();
    _storeLifecycle = AppLifecycleListener(onResume: _retryVisibleCatalogue);
    _purchaseSub = _billing.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isProcessingPurchase = false;
          _isRestoring = false;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: Duration(seconds: 3),
              content: Text(context.strings.premiumPurchaseError),
            ),
          );
      },
    );
    _loadCatalogue();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    try {
      final response = await _api.get('/purchase-campaigns/active');
      if (!mounted || response is! List) return;
      final offers = <String, Map<String, dynamic>>{};
      for (final raw in response) {
        if (raw is! Map<String, dynamic>) continue;
        final productId = raw['product_id'];
        final percent = raw['discount_percent'];
        if (productId is! String || percent is! int) continue;
        final previous = offers[productId];
        if (previous == null ||
            (previous['discount_percent'] as int) < percent) {
          offers[productId] = raw;
        }
      }
      setState(() => _campaignsFromBackend = offers);
      _refreshAvailableOffers();
    } catch (_) {
      // Brak informacji o kampanii nie może zablokować zwykłych zakupów.
    }
  }

  void _refreshAvailableOffers() {
    if (!mounted) return;
    final generation = ++_offerGeneration;
    final selectedProducts = <String, ProductDetails>{};
    final effectiveCampaigns = <String, Map<String, dynamic>>{};
    for (final id in kSubscriptionProductIds) {
      final regular = _billing.selectPreferredSubscriptionOffer(
        _allSubscriptionProducts,
        id,
      );
      if (regular != null) selectedProducts[id] = regular;
      final campaign = _campaignsFromBackend[id];
      if (campaign == null) continue;
      if (id == kMonthlyProductId &&
          regular != null &&
          hasGooglePlaySevenDayTrial(regular)) {
        continue;
      }
      if (Platform.isIOS) {
        effectiveCampaigns[id] = campaign;
        continue;
      }
      final basePlanId = campaign['android_base_plan_id'];
      final offerId = campaign['android_offer_id'];
      if (basePlanId is! String || offerId is! String) continue;
      final offer = _billing.selectAndroidSubscriptionOffer(
        _allSubscriptionProducts,
        productId: id,
        basePlanId: basePlanId,
        offerId: offerId,
      );
      // Nie pokazujemy rabatu, jeśli Google Play nie zwróciło tej oferty
      // jako dostępnej dla bieżącego użytkownika. Chroni to przed ekranem
      // z obietnicą -30%, po którym sklep naliczyłby cenę regularną.
      if (offer != null) {
        selectedProducts[id] = offer;
        effectiveCampaigns[id] = campaign;
      }
    }
    // Pakiety punktów korzystają z czasowej ceny produktu ustawionej w
    // odpowiednim sklepie. Kody ofertowe Apple dotyczą tylko subskrypcji.
    for (final id in kPointsProductIds) {
      final campaign = _campaignsFromBackend[id];
      if (campaign != null) effectiveCampaigns[id] = campaign;
    }
    setState(() {
      _products = selectedProducts;
      _activeOffers = effectiveCampaigns;
      _monthlyHasSevenDayTrial = false;
    });
    final monthly = selectedProducts[kMonthlyProductId];
    if (monthly != null) unawaited(_confirmMonthlyTrial(monthly, generation));
  }

  Future<void> _confirmMonthlyTrial(
    ProductDetails product,
    int generation,
  ) async {
    bool eligible;
    try {
      eligible = await _billing.hasSevenDayFreeTrial(product);
    } catch (_) {
      eligible = false;
    }
    if (!mounted ||
        generation != _offerGeneration ||
        !identical(_products[kMonthlyProductId], product))
      return;
    setState(() => _monthlyHasSevenDayTrial = eligible);
  }

  Future<void> _openOffer(String productId) async {
    final url = _activeOffers[productId]?['ios_offer_url'];
    if (url is! String) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'apps.apple.com' ||
        uri.path != '/redeem' ||
        uri.queryParameters['ctx'] != 'offercodes')
      return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.premiumAppleOfferOpenFailed)),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, strings: context.strings))),
        );
    }
  }

  @override
  void dispose() {
    _storeLifecycle.dispose();
    _purchaseSub?.cancel();
    super.dispose();
  }

  void _retryVisibleCatalogue() {
    if (_isProcessingPurchase ||
        _isRestoring ||
        (_products.isNotEmpty && _pointsProducts.isNotEmpty) ||
        !TickerMode.of(context) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    unawaited(_loadCatalogue());
  }

  Future<void> _loadCatalogue() async {
    if (_isLoadingCatalogue) return;
    setState(() {
      _isLoadingCatalogue = true;
      _productsError = null;
      _products = {};
      _allSubscriptionProducts = [];
      _pointsProducts = {};
      _monthlyHasSevenDayTrial = false;
      _offerGeneration++;
    });
    try {
      final available = await _billing.isAvailable().timeout(_storeTimeout);
      if (!mounted) return;
      if (!available) {
        setState(() {
          _isLoadingCatalogue = false;
          _productsError = context.strings.premiumPaymentsUnavailable(
            Platform.isIOS ? 'App Store' : 'Google Play',
          );
        });
        return;
      }

      final response = await _billing.queryCatalogue().timeout(_storeTimeout);
      if (!mounted) return;
      setState(() {
        _allSubscriptionProducts =
            response.productDetails
                .where(
                  (product) => kSubscriptionProductIds.contains(product.id),
                )
                .toList();
        _pointsProducts = {
          for (final product in response.productDetails)
            if (kPointsProductIds.contains(product.id)) product.id: product,
        };
        _isLoadingCatalogue = false;
      });
      _refreshAvailableOffers();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCatalogue = false;
        _productsError = context.strings.premiumSubscriptionPricesUnavailable;
      });
    }
  }

  Future<void> _buyPoints(ProductDetails product) async {
    setState(() => _isProcessingPurchase = true);
    try {
      await _billing.buyPoints(product);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingPurchase = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!mounted) return;
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _isProcessingPurchase = true);
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() {
            _isProcessingPurchase = false;
            _isRestoring = false;
          });
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 3),
                content: Text(
                  context.strings.premiumPurchaseFailed(
                    purchase.error?.message ??
                        context.strings.premiumUnknownError,
                  ),
                ),
              ),
            );
        }
        // Błąd zgłoszony przez sam sklep — nie ma czego potwierdzać
        // wobec backendu, ale trzeba domknąć transakcję po stronie
        // Google, jeśli tego wymaga.
        if (purchase.pendingCompletePurchase) {
          try {
            await _billing.completePurchase(purchase);
          } catch (_) {
            // A native bridge failure must never escape the stream callback.
            // The store keeps this transaction pending for a later retry.
          }
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.canceled) {
        setState(() {
          _isProcessingPurchase = false;
          _isRestoring = false;
        });
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final key =
            '${purchase.productID}:${purchase.purchaseID}:'
            '${purchase.verificationData.serverVerificationData}';
        if (_verifiedPurchases.contains(key) && !_isRestoring) continue;
        if (!_verifyingPurchases.add(key)) continue;
        if (_isRestoring) _restoreReceivedPurchase = true;
        setState(() => _isProcessingPurchase = true);
        try {
          if (await _verifyWithBackend(purchase)) _verifiedPurchases.add(key);
        } finally {
          _verifyingPurchases.remove(key);
        }
      }
    }
  }

  Future<bool> _verifyWithBackend(PurchaseDetails purchase) async {
    if (!mounted) return false;
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;
    final session = auth.sessionGeneration;
    bool isPurchaseSessionCurrent() =>
        userId != null &&
        auth.currentUser?.id == userId &&
        auth.sessionGeneration == session;
    final wasRestoring = _isRestoring;
    final alreadyHadPremium =
        Provider.of<AuthProvider>(
          context,
          listen: false,
        ).currentUser?.hasPremiumAccess ??
        false;
    // UWAGA (naprawa — poprawny identyfikator dla iOS): na Androidzie
    // serverVerificationData to prawidłowy token Google. Na iOS to samo
    // pole zawiera dane paragonu w starszym formacie — App Store Server
    // API (patrz backend, apple_app_store.py) wymaga natomiast ID
    // TRANSAKCJI, dostępnego jako purchase.purchaseID (odpowiednik
    // SKPaymentTransaction.transactionIdentifier).
    final purchaseToken =
        defaultTargetPlatform == TargetPlatform.iOS
            ? (purchase.purchaseID ??
                purchase.verificationData.serverVerificationData)
            : purchase.verificationData.serverVerificationData;

    // UWAGA (rozszerzenie): pakiety punktów to INNY rodzaj produktu
    // (konsumowalny, nie subskrypcja) i mają OSOBNĄ ścieżkę weryfikacji
    // na backendzie — rozpoznajemy je po identyfikatorze produktu.
    final isPointsPackage = {
      kPoints10ProductId,
      kPoints20ProductId,
      kPoints50ProductId,
    }.contains(purchase.productID);

    if (isPointsPackage) {
      return _verifyPointsWithBackend(purchase, purchaseToken);
    }

    try {
      final isRestore = purchase.status == PurchaseStatus.restored;
      final result =
          isRestore
              ? await _billing.restoreOnBackend(
                purchaseToken: purchaseToken,
                productId: purchase.productID,
              )
              : await _billing.verifyPurchase(
                purchaseToken: purchaseToken,
                productId: purchase.productID,
              );

      if (result['is_premium'] != true) {
        throw StateError('Subscription verification did not grant access');
      }

      final applied =
          userId != null &&
          auth.applyVerifiedSubscription(
            userId: userId,
            session: session,
            result: result,
          );

      // UWAGA: potwierdzamy zakup wobec Google TYLKO po tym, jak backend
      // faktycznie potwierdził go u Google i nadał premium — jeśli
      // backend odrzuci zakup (np. nieprawidłowy token), CELOWO NIE
      // wywołujemy completePurchase, żeby nie "zgubić" transakcji, którą
      // można by ponownie zweryfikować przez przywrócenie zakupów.
      if (purchase.pendingCompletePurchase) {
        await _billing.completePurchase(purchase);
      }

      if (!mounted) return true;
      if (result['is_premium'] == true) {
        if (isPurchaseSessionCurrent()) {
          if (applied) {
            unawaited(auth.loadProfile());
          } else {
            await auth.loadProfile();
          }
        }
        if (!mounted) return true;
        setState(() {
          _isProcessingPurchase = false;
          _isRestoring = false;
        });
        // Store callbacks can arrive after account changes or after another
        // route was opened. Finish the verified transaction, but only return
        // from the paywall that still owns this purchase's active session.
        if (!applied ||
            !isPurchaseSessionCurrent() ||
            !(ModalRoute.of(context)?.isCurrent ?? false)) {
          return true;
        }
        // Strumień sklepu potrafi ponownie przesłać stary zakup po
        // uruchomieniu aplikacji. Nie pokazujemy wtedy fałszywej,
        // ponownej aktywacji. Informacja pozostaje przy zakupie nowym
        // albo ręcznym przywróceniu zakupów.
        if (!alreadyHadPremium || wasRestoring) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 3),
                content: Text(
                  alreadyHadPremium
                      ? context.strings.premiumActive
                      : context.strings.premiumActivated,
                ),
              ),
            );
        }
        // Premium może być osobną trasą albo zakładką ekranu głównego.
        // Zamknięcie zakładki przez pop() usuwało jedyną trasę /home
        // i pozostawiało użytkownika z czarnym ekranem.
        if (!alreadyHadPremium &&
            widget.popAfterSuccess &&
            Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _isProcessingPurchase = false;
        _isRestoring = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              context.strings.premiumPurchaseVerificationFailed(
                friendlyError(e, strings: context.strings),
              ),
            ),
          ),
        );
      return false;
    }
  }

  /// Weryfikacja zakupu PAKIETU PUNKTÓW — osobna od subskrypcji, bo to
  /// inny endpoint backendu i inny rezultat (saldo punktów, nie status
  /// premium). Finish only after the server has durably credited the points.
  /// Android consumption is performed by the backend after that commit.
  Future<bool> _verifyPointsWithBackend(
    PurchaseDetails purchase,
    String purchaseToken,
  ) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;
    final session = auth.sessionGeneration;
    try {
      final newBalance = await _billing.verifyPointsPurchase(
        purchaseToken: purchaseToken,
        productId: purchase.productID,
      );

      final applied =
          userId != null &&
          auth.applyVerifiedPoints(
            userId: userId,
            session: session,
            balance: newBalance,
          );

      if (purchase.pendingCompletePurchase) {
        await _billing.completePurchase(purchase);
      }

      if (!mounted) return true;
      if (applied) {
        unawaited(auth.loadProfile());
      } else {
        await auth.loadProfile();
      }
      if (!mounted) return true;
      setState(() {
        _isProcessingPurchase = false;
        _isRestoring = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(context.strings.premiumPointsAdded(newBalance)),
          ),
        );
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _isProcessingPurchase = false;
        _isRestoring = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              context.strings.premiumPurchaseVerificationFailed(
                friendlyError(e, strings: context.strings),
              ),
            ),
          ),
        );
      return false;
    }
  }

  Future<void> _buy(String productId) async {
    final product = _products[productId];
    if (product == null) return;
    setState(() => _isProcessingPurchase = true);
    try {
      await _billing.buy(product);
      // Wynik (sukces/błąd) przyjdzie asynchronicznie przez purchaseStream
      // — patrz _handlePurchaseUpdates.
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingPurchase = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              context.strings.premiumPurchaseStartFailed(
                friendlyError(e, strings: context.strings),
              ),
            ),
          ),
        );
    }
  }

  Future<void> _useSubscriptionOffer(String productId) async {
    final usesTrial =
        productId == kMonthlyProductId && _monthlyHasSevenDayTrial;
    if (!usesTrial && Platform.isIOS && _activeOffers.containsKey(productId)) {
      await _openOffer(productId);
      return;
    }
    await _buy(productId);
  }

  Future<void> _usePointsOffer(ProductDetails product) async {
    await _buyPoints(product);
  }

  Future<void> _restore() async {
    if (_isProcessingPurchase || _isRestoring) return;
    final generation = ++_restoreGeneration;
    _restoreReceivedPurchase = false;
    setState(() => _isRestoring = true);
    try {
      await _billing.restorePurchases().timeout(_storeTimeout);
      // Jeśli coś się znajdzie, przyjdzie przez purchaseStream jako
      // PurchaseStatus.restored — patrz _handlePurchaseUpdates.
      // Dajemy chwilę na dotarcie zdarzenia, zanim uznamy, że nic nie ma.
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      if (_isRestoring &&
          generation == _restoreGeneration &&
          !_restoreReceivedPurchase) {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: Duration(seconds: 3),
              content: Text(context.strings.premiumRestoreEmpty),
            ),
          );
      }
    } catch (e) {
      if (!mounted ||
          generation != _restoreGeneration ||
          _restoreReceivedPurchase)
        return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
          ),
        );
    }
  }

  /// Karta bezpośredniej akcji Premium — dotknięcie prowadzi PROSTO do
  /// danej funkcji (nie tylko jej opisuje). Dla kont bez Premium mała
  /// plakietka kłódki sygnalizuje, że dotknięcie skończy się zachętą do
  /// zakupu wewnątrz docelowego ekranu (te ekrany już mają wbudowaną
  /// bramkę Premium z wcześniejszych sesji).
  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPremium,
    required VoidCallback onTap,
    // UWAGA (naprawa widoczności — punkty premium): dotąd zablokowana
    // pozycja pokazywała TYLKO kłódkę, sugerującą "wymaga Premium", bez
    // żadnej wzmianki, że dla TEJ konkretnej funkcji (AI) istnieje też
    // alternatywna ścieżka za punkty. Stąd wrażenie, że możliwości
    // wymiany punktów na zapytanie w ogóle nie ma — mimo że backend już
    // ją obsługuje (patrz ai_import_recipe). Ten parametr, gdy podany,
    // pokazuje monetę zamiast/obok kłódki i cenę punktową w podtytule.
    int? pointsAlternativeCost,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outlineColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryTintColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.actionPrimaryColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.fade,
                        ),
                      ),
                      if (!isPremium && pointsAlternativeCost == null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.lock_outline,
                          size: 13,
                          color: AppTheme.textSecondary.withOpacity(0.6),
                        ),
                      ],
                      if (!isPremium && pointsAlternativeCost != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.toll,
                                size: 11,
                                color: AppTheme.accentColor,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$pointsAlternativeCost',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    !isPremium && pointsAlternativeCost != null
                        ? context.strings.premiumQuickActionPoints(
                          subtitle,
                          pointsAlternativeCost,
                        )
                        : subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  static List<_PremiumFeature> _features(BuildContext context) => [
    _PremiumFeature(
      icon: Icons.auto_mode_outlined,
      title: context.strings.premiumAutomaticWeekTitle,
      description: context.strings.premiumAutomaticWeekDescription,
    ),
    _PremiumFeature(
      icon: Icons.qr_code_2,
      title: context.strings.premiumBatchTitle,
      description: context.strings.premiumBatchDescription,
    ),
    _PremiumFeature(
      icon: Icons.all_inclusive,
      title: context.strings.premiumUnlimitedPlansTitle,
      description: context.strings.premiumUnlimitedPlansDescription,
    ),
    _PremiumFeature(
      icon: Icons.menu_book_outlined,
      title: context.strings.premiumAiRecipesTitle,
      description: context.strings.premiumAiRecipesDescription,
    ),
    _PremiumFeature(
      icon: Icons.history,
      title: context.strings.premiumFullDiaryTitle,
      description: context.strings.premiumFullDiaryDescription,
    ),
    _PremiumFeature(
      icon: Icons.calendar_view_week,
      title: context.strings.premiumUnlimitedListsTitle,
      description: context.strings.premiumUnlimitedListsDescription,
    ),
  ];

  Widget _buildFeatureRow(_PremiumFeature feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(feature.icon, color: AppTheme.actionPrimaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanPricing(BuildContext context) =>
      Column(key: _pricingSectionKey, children: _buildPricingSection(context));

  Widget _buildSubscriptionSection(BuildContext context) => Column(
    children: [_buildPlanPricing(context), _buildSubscriptionFooter(context)],
  );

  Widget _buildSubscriptionFooter(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: _isRestoring || _isProcessingPurchase ? null : _restore,
            icon:
                _isRestoring
                    ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.restore, size: 16),
            label: Text(context.strings.premiumRestorePurchases),
          ),
        ),
        const SizedBox(height: 8),
        _buildLegalFooter(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final isPremium = user?.hasPremiumAccess ?? false;
    final features = _features(context);
    final isGeneralOffer = !isPremium && widget.offerContext == null;
    final isContextualOffer = !isPremium && widget.offerContext != null;
    // A prospective subscriber sees three benefits and the store's offer
    // before operational shortcuts. Existing subscribers keep their shortcuts.
    final primaryFeatures = [features[0], features[5], features[3]];
    final remainingFeatures =
        isGeneralOffer ? [features[1], features[2], features[4]] : features;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              context.strings.premiumProductName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            pinned: true,
            centerTitle: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (isContextualOffer) ...[
                  // The scroll target exists whenever the offer button is visible.
                  Column(
                    children: [
                      _buildContextualOfferCard(context),
                      const SizedBox(height: 20),
                      _buildPlanPricing(context),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._buildPointsSection(context),
                  const SizedBox(height: 16),
                  _buildSubscriptionFooter(context),
                  const SizedBox(height: 26),
                ] else if (!isPremium) ...[
                  _buildOfferIntro(context),
                  const SizedBox(height: 20),
                  ...primaryFeatures.map(_buildFeatureRow),
                  const SizedBox(height: 8),
                  _buildSubscriptionSection(context),
                  const SizedBox(height: 26),
                ],
                // Skróty do FAKTYCZNYCH funkcji Premium — bezpośrednie
                // akcje, nie tylko opis. Dla kont bez Premium dotknięcie
                // prowadzi do tego samego miejsca, gdzie wbudowana
                // bramka Premium (już istniejąca w tych ekranach) sama
                // pokaże zachętę do zakupu we właściwym kontekście.
                _buildQuickAction(
                  context,
                  icon: Icons.auto_mode_outlined,
                  title: context.strings.premiumAutomaticWeekTitle,
                  subtitle: context.strings.premiumAutomaticWeekSubtitle,
                  isPremium: isPremium,
                  onTap: () {
                    if (!isPremium) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              context.strings.premiumAutomaticWeekRequired,
                            ),
                          ),
                        );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WeeklyPlanAutomationScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildQuickAction(
                  context,
                  icon: Icons.menu_book_outlined,
                  title: context.strings.premiumAiActionTitle,
                  subtitle: context.strings.premiumAiActionSubtitle,
                  isPremium: isPremium,
                  pointsAlternativeCost: 2,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AiAddRecipeScreen(),
                        ),
                      ),
                ),
                const SizedBox(height: 10),
                _buildQuickAction(
                  context,
                  icon: Icons.qr_code_2,
                  title: context.strings.premiumBatchActionTitle,
                  subtitle: context.strings.premiumBatchActionSubtitle,
                  isPremium: isPremium,
                  onTap: () async {
                    if (!isPremium) {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder:
                              (_) => const BatchBarcodeScannerScreen(
                                previewOnly: true,
                              ),
                        ),
                      );
                      return;
                    }
                    final completed = await Navigator.of(context).push<int>(
                      MaterialPageRoute(
                        builder: (_) => const BatchBarcodeScannerScreen(),
                      ),
                    );
                    if (!context.mounted || completed == null || completed == 0)
                      return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.strings.premiumBatchCompleted(completed),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildQuickAction(
                  context,
                  icon: Icons.groups,
                  title: context.strings.premiumPublishActionTitle,
                  subtitle: context.strings.premiumPublishActionSubtitle,
                  // Submission is available to every signed-in account;
                  // publication still goes through the existing review.
                  isPremium: true,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => const RecipesScreen(
                                initialMyRecipesOnly: true,
                              ),
                        ),
                      ),
                ),
                const SizedBox(height: 10),
                _buildQuickAction(
                  context,
                  icon: Icons.shopping_cart,
                  title: context.strings.premiumRecipeListsTitle,
                  subtitle: context.strings.premiumRecipeListsSubtitle,
                  isPremium: isPremium,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecipesScreen(),
                        ),
                      ),
                ),
                const SizedBox(height: 10),
                _buildQuickAction(
                  context,
                  icon: Icons.kitchen_outlined,
                  title: context.strings.premiumCookFromPantryTitle,
                  subtitle: context.strings.premiumCookFromPantrySubtitle,
                  isPremium: isPremium,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const IngredientMatchSelectScreen(),
                        ),
                      ),
                ),
                const SizedBox(height: 10),
                _buildQuickAction(
                  context,
                  icon: Icons.inventory_2_outlined,
                  title: context.strings.premiumPantryActionTitle,
                  subtitle: context.strings.premiumPantryActionSubtitle,
                  // Spiżarnia jest dostępna dla WSZYSTKICH kont, nie tylko
                  // Premium — celowo zawsze bez plakietki kłódki.
                  isPremium: true,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PantryScreen()),
                      ),
                ),
                const SizedBox(height: 28),
                ...remainingFeatures.map(_buildFeatureRow),
                const SizedBox(height: 12),
                if (isPremium) _buildSubscriptionSection(context),
                if (!isContextualOffer) ...[
                  const SizedBox(height: 24),
                  ..._buildPointsSection(context),
                  const SizedBox(height: 12),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Wymagane przez Apple Guideline 3.1.2: przy subskrypcjach
  /// auto-odnawialnych trzeba pokazać tytuł, długość i cenę każdej
  /// (już widoczne w kartach wyżej), informację o automatycznym
  /// odnawianiu oraz KLIKALNE linki do regulaminu (EULA) i polityki
  /// prywatności — nie wystarczy sam link do polityki prywatności.
  Widget _buildLegalFooter(BuildContext context) {
    return Column(
      children: [
        Text(
          context.strings.premiumSubscriptionLegal(
            Platform.isIOS ? 'App Store' : 'Google Play',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        const AppDocumentLinks(),
      ],
    );
  }

  /// Buduje sekcję cennika: status "już masz Premium", stan ładowania,
  /// błąd albo karty z prawdziwymi, lokalnymi cenami ze sklepu.
  /// Przywracanie zakupów jest niezależne od dostępności cennika.
  List<Widget> _buildPricingSection(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    if (user?.hasPremiumAccess ?? false) {
      final daysLeft = user!.premiumDaysRemaining;
      return [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.strings.premiumAlreadyActive,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (daysLeft != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            daysLeft == 0
                                ? context.strings.premiumExpiresToday
                                : context.strings.premiumDaysRemaining(
                                  daysLeft,
                                ),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.strings.premiumAutomaticWeekSubtitle,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WeeklyPlanAutomationScreen(),
                      ),
                    ),
                icon: const Icon(Icons.auto_mode_outlined),
                label: Text(context.strings.premiumAutomaticWeekTitle),
              ),
            ],
          ),
        ),
      ];
    }

    if (_isLoadingCatalogue) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_products.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                _productsError ??
                    context.strings.premiumSubscriptionPricesUnavailable,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.errorColor),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('premium-plans-retry'),
                onPressed: _loadCatalogue,
                child: Text(context.strings.premiumRetry),
              ),
            ],
          ),
        ),
      ];
    }

    final weekly = _products[kWeeklyProductId];
    final monthly = _products[kMonthlyProductId];
    final yearly = _products[kYearlyProductId];
    final annualSaving = annualSavingsPercent(monthly, yearly);

    return [
      if (monthly != null)
        _buildPricingCard(
          context: context,
          title: context.strings.premiumMonthly,
          price: _billing.regularSubscriptionPrice(monthly),
          trialLabel:
              _monthlyHasSevenDayTrial
                  ? context.strings.premiumMonthlyTrial(7)
                  : null,
          trialDisclosure:
              _monthlyHasSevenDayTrial
                  ? (Platform.isIOS
                      ? context.strings.premiumTrialDisclosureApple
                      : context.strings.premiumTrialDisclosureGoogle)
                  : null,
          highlight: false,
          primaryAction: true,
          discountPercent:
              _monthlyHasSevenDayTrial
                  ? null
                  : _activeOffers[kMonthlyProductId]?['discount_percent']
                      as int?,
          onTap:
              _isProcessingPurchase
                  ? null
                  : () => _useSubscriptionOffer(kMonthlyProductId),
        ),
      if (monthly != null) const SizedBox(height: 12),
      if (yearly != null)
        _buildPricingCard(
          context: context,
          title: context.strings.premiumYearly,
          price: _billing.regularSubscriptionPrice(yearly),
          badge:
              _activeOffers.containsKey(kYearlyProductId) ||
                      annualSaving == null
                  ? null
                  : context.strings.premiumYearlySaving(annualSaving),
          highlight: true,
          discountPercent:
              _activeOffers[kYearlyProductId]?['discount_percent'] as int?,
          onTap:
              _isProcessingPurchase
                  ? null
                  : () => _useSubscriptionOffer(kYearlyProductId),
        ),
      if (weekly != null) ...[
        const SizedBox(height: 12),
        _buildPricingCard(
          context: context,
          title: context.strings.premiumWeekly,
          price: _billing.regularSubscriptionPrice(weekly),
          highlight: false,
          discountPercent:
              _activeOffers[kWeeklyProductId]?['discount_percent'] as int?,
          onTap:
              _isProcessingPurchase
                  ? null
                  : () => _useSubscriptionOffer(kWeeklyProductId),
        ),
      ],
      const SizedBox(height: 20),
    ];
  }

  /// Sekcja zakupu pakietów punktów premium — osobna od subskrypcji
  /// (patrz komentarz w _verifyWithBackend): 2 punkty = jedno zapytanie
  /// do AI, dla kont, które nie chcą pełnej subskrypcji, ale chcą
  /// jednorazowo skorzystać z rozpoznawania przepisu przez AI.
  List<Widget> _buildPointsSection(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentBalance = auth.currentUser?.premiumPoints ?? 0;

    return [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.toll_outlined, color: AppTheme.accentColor, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.strings.premiumPointsTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            context.strings.premiumPointsBalance(currentBalance),
            style: TextStyle(
              color: AppTheme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        context.strings.premiumPointsExplanation,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      const SizedBox(height: 12),
      if (_isLoadingCatalogue)
        const Center(child: CircularProgressIndicator())
      else if (_pointsProducts.isEmpty) ...[
        Text(
          context.strings.premiumPointsPricesUnavailable,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('premium-points-retry'),
            onPressed: _loadCatalogue,
            child: Text(context.strings.premiumRetry),
          ),
        ),
      ] else
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth =
                constraints.maxWidth < 420
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_pointsProducts[kPoints10ProductId] != null)
                  SizedBox(
                    width: cardWidth,
                    child: _buildPointsCard(
                      points: 10,
                      price: _pointsProducts[kPoints10ProductId]!.price,
                      discountPercent:
                          _activeOffers[kPoints10ProductId]?['discount_percent']
                              as int?,
                      onTap:
                          _isProcessingPurchase
                              ? null
                              : () =>
                                  _activeOffers.containsKey(kPoints10ProductId)
                                      ? _usePointsOffer(
                                        _pointsProducts[kPoints10ProductId]!,
                                      )
                                      : _buyPoints(
                                        _pointsProducts[kPoints10ProductId]!,
                                      ),
                    ),
                  ),
                if (_pointsProducts[kPoints20ProductId] != null) ...[
                  SizedBox(
                    width: cardWidth,
                    child: _buildPointsCard(
                      points: 20,
                      price: _pointsProducts[kPoints20ProductId]!.price,
                      discountPercent:
                          _activeOffers[kPoints20ProductId]?['discount_percent']
                              as int?,
                      onTap:
                          _isProcessingPurchase
                              ? null
                              : () =>
                                  _activeOffers.containsKey(kPoints20ProductId)
                                      ? _usePointsOffer(
                                        _pointsProducts[kPoints20ProductId]!,
                                      )
                                      : _buyPoints(
                                        _pointsProducts[kPoints20ProductId]!,
                                      ),
                    ),
                  ),
                ],
                if (_pointsProducts[kPoints50ProductId] != null) ...[
                  SizedBox(
                    width: cardWidth,
                    child: _buildPointsCard(
                      points: 50,
                      price: _pointsProducts[kPoints50ProductId]!.price,
                      discountPercent:
                          _activeOffers[kPoints50ProductId]?['discount_percent']
                              as int?,
                      highlight: true,
                      onTap:
                          _isProcessingPurchase
                              ? null
                              : () =>
                                  _activeOffers.containsKey(kPoints50ProductId)
                                      ? _usePointsOffer(
                                        _pointsProducts[kPoints50ProductId]!,
                                      )
                                      : _buyPoints(
                                        _pointsProducts[kPoints50ProductId]!,
                                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
    ];
  }

  Widget _buildPointsCard({
    required int points,
    required String price,
    required VoidCallback? onTap,
    int? discountPercent,
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color:
              highlight
                  ? AppTheme.accentColor.withOpacity(0.12)
                  : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                highlight
                    ? AppTheme.accentColor
                    : AppTheme.textSecondary.withOpacity(0.2),
            width: highlight ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            CampaignIcon(
              icon: Icons.toll,
              color: AppTheme.accentColor,
              discountPercent: discountPercent,
            ),
            const SizedBox(height: 6),
            Text(
              context.strings.premiumPointsAmount(points),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              discountPercent == null
                  ? price
                  : context.strings.premiumPromotionalPrice(price),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              context.strings.premiumPointsUses(points ~/ 2, points),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onTap,
              child: Text(
                discountPercent == null
                    ? context.strings.aiEditBuyPoints
                    : Platform.isIOS
                    ? context.strings.premiumBuyInApple
                    : context.strings.premiumBuyInGoogle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required BuildContext context,
    required String title,
    required String price,
    String? trialLabel,
    String? trialDisclosure,
    String? badge,
    int? discountPercent,
    required bool highlight,
    bool primaryAction = false,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final annualSurface =
        theme.brightness == Brightness.dark
            ? const Color(0xFF2F2A1E)
            : const Color(0xFFF4EFE1);
    final offerPrice =
        trialLabel != null
            ? context.strings.premiumPriceAfterTrial(price)
            : discountPercent == null
            ? price
            : Platform.isIOS
            ? context.strings.premiumPriceBeforeCode(price)
            : context.strings.premiumPromotionalPrice(price);
    final label =
        trialLabel != null
            ? context.strings.premiumTryFree
            : discountPercent == null
            ? context.strings.premiumBuy
            : Platform.isIOS
            ? context.strings.premiumRedeemCode
            : context.strings.premiumBuyDiscount;
    final actionContent =
        _isProcessingPurchase
            ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
            : Text(label, textAlign: TextAlign.center);

    return Container(
      key: highlight ? const ValueKey('premium-yearly-card') : null,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: highlight ? annualSurface : colors.surface,
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badge != null)
                Text(
                  badge,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.actionPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (discountPercent != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: CampaignIcon(
                icon: Icons.workspace_premium_outlined,
                color: AppTheme.actionPrimaryColor,
                discountPercent: discountPercent,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (trialLabel != null) ...[
            Text(
              trialLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.actionPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            offerPrice,
            style:
                trialLabel == null && discountPercent == null
                    ? theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    )
                    : theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (primaryAction)
            ElevatedButton(onPressed: onTap, child: actionContent)
          else
            OutlinedButton(onPressed: onTap, child: actionContent),
          if (trialDisclosure != null) ...[
            const SizedBox(height: 8),
            Text(
              trialDisclosure,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumFeature {
  final IconData icon;
  final String title;
  final String description;

  const _PremiumFeature({
    required this.icon,
    required this.title,
    required this.description,
  });
}
