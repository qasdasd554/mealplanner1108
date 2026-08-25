import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/billing_service.dart';
import '../../utils/error_utils.dart';
import '../recipes/recipes_screen.dart';
import '../recipes/ai_add_recipe_screen.dart';

/// Ekran prezentacji subskrypcji Premium — lista korzyści + przyciski
/// zakupu, w pełni podłączone pod Google Play Billing. Backend (nie ta
/// aplikacja) ostatecznie decyduje, czy nadać dostęp premium — dopiero
/// PO zweryfikowaniu tokenu zakupu bezpośrednio u Google.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final BillingService _billing = BillingService();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool _isLoadingProducts = true;
  Map<String, ProductDetails> _products = {};
  String? _productsError;

  // Podczas przetwarzania zakupu blokujemy przyciski i pokazujemy
  // spinner — zakup przechodzi przez kilka asynchronicznych kroków
  // (Google -> backend -> potwierdzenie), więc to może potrwać kilka
  // sekund.
  bool _isProcessingPurchase = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _purchaseSub = _billing.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        if (!mounted) return;
        setState(() => _isProcessingPurchase = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wystąpił błąd podczas zakupu.')),
        );
      },
    );
    _loadProducts();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });
    try {
      final available = await _billing.isAvailable();
      if (!available) {
        if (!mounted) return;
        setState(() {
          _isLoadingProducts = false;
          _productsError = 'Płatności są niedostępne na tym urządzeniu (sprawdź konto Google Play).';
        });
        return;
      }

      final response = await _billing.queryProducts();
      if (!mounted) return;
      setState(() {
        _products = {for (final p in response.productDetails) p.id: p};
        _isLoadingProducts = false;
        if (response.productDetails.isEmpty) {
          _productsError = 'Nie udało się pobrać cen subskrypcji. Spróbuj ponownie za chwilę.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _productsError = friendlyError(e);
      });
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Zakup nie powiódł się: ${purchase.error?.message ?? "nieznany błąd"}')),
          );
        }
        // Błąd zgłoszony przez sam sklep — nie ma czego potwierdzać
        // wobec backendu, ale trzeba domknąć transakcję po stronie
        // Google, jeśli tego wymaga.
        if (purchase.pendingCompletePurchase) {
          await _billing.completePurchase(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) setState(() => _isProcessingPurchase = false);
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        await _verifyWithBackend(purchase);
      }
    }
  }

  Future<void> _verifyWithBackend(PurchaseDetails purchase) async {
    final purchaseToken = purchase.verificationData.serverVerificationData;
    try {
      final isRestore = purchase.status == PurchaseStatus.restored;
      final result = isRestore
          ? await _billing.restoreOnBackend(purchaseToken: purchaseToken, productId: purchase.productID)
          : await _billing.verifyPurchase(purchaseToken: purchaseToken, productId: purchase.productID);

      // UWAGA: potwierdzamy zakup wobec Google TYLKO po tym, jak backend
      // faktycznie potwierdził go u Google i nadał premium — jeśli
      // backend odrzuci zakup (np. nieprawidłowy token), CELOWO NIE
      // wywołujemy completePurchase, żeby nie "zgubić" transakcji, którą
      // można by ponownie zweryfikować (np. przez "Przywróć zakupy").
      if (purchase.pendingCompletePurchase) {
        await _billing.completePurchase(purchase);
      }

      if (!mounted) return;
      if (result['is_premium'] == true) {
        await Provider.of<AuthProvider>(context, listen: false).loadProfile();
        if (!mounted) return;
        setState(() {
          _isProcessingPurchase = false;
          _isRestoring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium aktywowane — dziękujemy!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingPurchase = false;
        _isRestoring = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się potwierdzić zakupu: ${friendlyError(e)}')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się rozpocząć zakupu: ${friendlyError(e)}')),
      );
    }
  }

  Future<void> _restore() async {
    setState(() => _isRestoring = true);
    try {
      await _billing.restorePurchases();
      // Jeśli coś się znajdzie, przyjdzie przez purchaseStream jako
      // PurchaseStatus.restored — patrz _handlePurchaseUpdates.
      // Dajemy chwilę na dotarcie zdarzenia, zanim uznamy, że nic nie ma.
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      if (_isRestoring) {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie znaleziono żadnych wcześniejszych zakupów do przywrócenia.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.secondaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (!isPremium) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_outline, size: 13, color: AppTheme.textSecondary.withOpacity(0.6)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  static const List<_PremiumFeature> _features = [
    _PremiumFeature(
      icon: Icons.all_inclusive,
      title: 'Plany posiłków bez limitu',
      description: 'Generuj tyle planów, ile chcesz — bez dziennego ograniczenia.',
    ),
    _PremiumFeature(
      icon: Icons.auto_awesome,
      title: 'Przepisy rozpoznawane przez AI',
      description: 'Dodawaj własne przepisy z wklejonego tekstu albo zdjęcia.',
    ),
    _PremiumFeature(
      icon: Icons.history,
      title: 'Pełna historia śledzenia',
      description: 'Przeglądaj całą historię kalorii, bez limitu 30 dni wstecz.',
    ),
    _PremiumFeature(
      icon: Icons.calendar_view_week,
      title: 'Wiele planów naraz',
      description: 'Osobny plan na dni robocze i osobny na weekend — jednocześnie.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // UWAGA (przebudowa): zakładka Premium ma pokazywać FAKTYCZNE
    // funkcje Premium (bezpośrednie skróty), nie tylko listę/tabelę —
    // tabela porównawcza przeniesiona do Profilu (PremiumComparisonTable).
    final user = Provider.of<AuthProvider>(context).currentUser;
    final isPremium = user?.hasPremiumAccess ?? false;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6D28D9), Color(0xFFE0A62E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 40),
                      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 12),
                      const Text(
                        'Meal Planner Premium',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: 4),
                      Text(
                        'Więcej możliwości dla Twojej kuchni',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                      ).animate().fadeIn(delay: 250.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Skróty do FAKTYCZNYCH funkcji Premium — bezpośrednie
                // akcje, nie tylko opis. Dla kont bez Premium dotknięcie
                // prowadzi do tego samego miejsca, gdzie wbudowana
                // bramka Premium (już istniejąca w tych ekranach) sama
                // pokaże zachętę do zakupu we właściwym kontekście.
                _buildQuickAction(
                  context,
                  icon: Icons.auto_awesome,
                  title: 'Dodaj przepis przez AI',
                  subtitle: 'Zdjęcie, tekst albo link — AI zrobi resztę',
                  isPremium: isPremium,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiAddRecipeScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                _buildQuickAction(
                  context,
                  icon: Icons.groups,
                  title: 'Publikuj przepisy we wspólnocie',
                  subtitle: 'Podziel się swoimi przepisami z innymi',
                  isPremium: isPremium,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RecipesScreen(initialMyRecipesOnly: true)),
                  ),
                ),
                const SizedBox(height: 10),
                _buildQuickAction(
                  context,
                  icon: Icons.shopping_cart,
                  title: 'Listy zakupów z przepisów',
                  subtitle: 'Do 5 zapisanych list (standard: 1)',
                  isPremium: isPremium,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RecipesScreen()),
                  ),
                ),
                const SizedBox(height: 28),
                ..._features.asMap().entries.map((entry) {
                  final index = entry.key;
                  final feature = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(feature.icon, color: AppTheme.secondaryColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feature.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                feature.description,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (300 + index * 100).ms).slideX(begin: 0.05, end: 0);
                }),
                const SizedBox(height: 12),
                ..._buildPricingSection(context),
                const SizedBox(height: 12),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Buduje sekcję cennika: status "już masz Premium", stan ładowania,
  /// błąd, albo dwie karty z PRAWDZIWYMI, lokalnymi cenami ze sklepu.
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
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Masz już aktywne Premium', style: TextStyle(fontWeight: FontWeight.bold)),
                    if (daysLeft != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        daysLeft == 0 ? 'Wygasa dziś' : 'Aktywne jeszcze przez $daysLeft ${daysLeft == 1 ? "dzień" : "dni"}',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 700.ms),
      ];
    }

    if (_isLoadingProducts) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (_productsError != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(_productsError!, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.errorColor)),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadProducts, child: const Text('Spróbuj ponownie')),
            ],
          ),
        ),
      ];
    }

    final weekly = _products[kWeeklyProductId];
    final monthly = _products[kMonthlyProductId];
    final yearly = _products[kYearlyProductId];

    return [
      if (weekly != null)
        _buildPricingCard(
          context: context,
          title: 'Tygodniowo',
          price: weekly.price,
          period: '',
          highlight: false,
          onTap: _isProcessingPurchase ? null : () => _buy(kWeeklyProductId),
        ).animate().fadeIn(delay: 650.ms),
      if (weekly != null) const SizedBox(height: 12),
      if (monthly != null)
        _buildPricingCard(
          context: context,
          title: 'Miesięcznie',
          price: monthly.price,
          period: '',
          highlight: false,
          onTap: _isProcessingPurchase ? null : () => _buy(kMonthlyProductId),
        ).animate().fadeIn(delay: 700.ms),
      if (monthly != null) const SizedBox(height: 12),
      if (yearly != null)
        _buildPricingCard(
          context: context,
          title: 'Rocznie',
          price: yearly.price,
          period: '',
          badge: 'Oszczędzasz 17%',
          highlight: true,
          onTap: _isProcessingPurchase ? null : () => _buy(kYearlyProductId),
        ).animate().fadeIn(delay: 800.ms),
      const SizedBox(height: 20),
      Text(
        'Subskrypcję można anulować w dowolnym momencie w ustawieniach Google Play.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton.icon(
          onPressed: _isRestoring ? null : _restore,
          icon: _isRestoring
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.restore, size: 16),
          label: const Text('Przywróć zakupy'),
        ),
      ),
    ];
  }

  Widget _buildPricingCard({
    required BuildContext context,
    required String title,
    required String price,
    required String period,
    String? badge,
    required bool highlight,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: highlight
            ? const LinearGradient(
                colors: [Color(0xFFF5C24D), Color(0xFFE0A62E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: highlight ? null : AppTheme.surfaceColor,
        border: highlight ? null : Border.all(color: AppTheme.textSecondary.withOpacity(0.15)),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: const Color(0xFFE0A62E).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: highlight ? Colors.white : null,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: price,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: highlight ? Colors.white : AppTheme.primaryColor,
                          ),
                        ),
                        if (period.isNotEmpty)
                          TextSpan(
                            text: ' $period',
                            style: TextStyle(
                              fontSize: 13,
                              color: highlight ? Colors.white.withOpacity(0.85) : AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: onTap,
                style: highlight
                    ? ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFE0A62E),
                        minimumSize: const Size(110, 44),
                      )
                    : ElevatedButton.styleFrom(minimumSize: const Size(110, 44)),
                child: _isProcessingPurchase
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kup Premium'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumFeature {
  final IconData icon;
  final String title;
  final String description;

  const _PremiumFeature({required this.icon, required this.title, required this.description});
}
