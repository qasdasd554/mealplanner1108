import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/wellness_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/premium_feature_tag.dart';
import '../../widgets/barcode_destination_sheet.dart';
import '../../widgets/user_avatar.dart';
import '../../models/meal_plan.dart';
import '../recipes/recipes_screen.dart';
import '../recipes/recipe_leaderboard_screen.dart';
import '../recipes/pantry_screen.dart';
import '../recipes/ai_add_recipe_screen.dart';
import '../batch_barcode_scanner_screen.dart';
import '../../widgets/decorative_circles.dart';
import '../shopping/shopping_list_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/premium_screen.dart';
import '../tracker/calorie_tracker_screen.dart';
import '../../data/cooking_tips.dart';
import '../../services/app_review_service.dart';
import '../../services/contextual_premium_offer_service.dart';
import '../../services/premium_offer_success_signal.dart';
import '../../services/api_client.dart';
import 'cooking_tips_screen.dart';
import '../../l10n/market_locale.dart';
import '../../l10n/recipe_content.dart';
import '../../l10n/catalog_labels.dart';
import '../../widgets/adaptive_action_tile.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  late final List<Widget?> _tabs;
  final _appReview = AppReviewService();
  final _reviewSchedule = ReviewPromptSchedule();
  Timer? _reviewTimer;
  Timer? _premiumSuccessTimer;
  String? _pendingReviewUserId;
  int? _pendingReviewGeneration;

  @override
  void initState() {
    super.initState();
    AppReviewSignal.successfulActions.addListener(_queueAppReview);
    PremiumOfferSuccessSignal.events.addListener(_queuePremiumAfterSuccess);
    _currentIndex = widget.initialIndex.clamp(0, 5);
    // Zakładki tworzymy dopiero przy pierwszym wejściu, ale później
    // zachowujemy ich State. Wcześniej `tabs[_currentIndex]` usuwało ekran
    // Przepisów z drzewa po każdej zmianie zakładki, więc powrót uruchamiał
    // initState i ponownie pobierał całą listę z sieci.
    _tabs = List<Widget?>.filled(6, null);
    _tabs[0] = const HomeTab();
    _ensureTab(_currentIndex);
    // Pobierz plany posiłków na start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MealPlanProvider>(context, listen: false).loadPlans();
      Provider.of<StoreProvider>(context, listen: false).loadStores();
      // Podsumowanie dnia (kcal/makro) na ekranie głównym — bez tego
      // FoodLogProvider.summary zostawałby null, dopóki użytkownik nie
      // odwiedziłby osobno ekranu Śledzenia.
      Provider.of<FoodLogProvider>(
        context,
        listen: false,
      ).fetchLogsForDate(DateTime.now());
      // Nawodnienie na pasku ekranu startowego — z tego samego powodu co
      // wyżej: bez tego pasek pokazywałby 0 ml, dopóki użytkownik nie
      // wszedłby osobno w zakładkę Śledzenie.
      Provider.of<WellnessProvider>(
        context,
        listen: false,
      ).loadForDate(DateTime.now());
    });
  }

  Widget _createTab(int index) => switch (index) {
    0 => const HomeTab(),
    1 => const RecipesScreen(),
    2 => const ShoppingListScreen(isTab: true),
    3 => const CalorieTrackerScreen(),
    4 => const PremiumScreen(popAfterSuccess: false),
    5 => const ProfileScreen(),
    _ => const SizedBox.shrink(),
  };

  void _queueAppReview() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;
    final generation = ApiClient().sessionGeneration;
    _reviewTimer?.cancel();
    if (!_reviewSchedule.recordSuccess(userId, generation, DateTime.now()))
      return;
    _pendingReviewUserId = userId;
    _pendingReviewGeneration = generation;
    _reviewTimer = Timer(ReviewPromptSchedule.quietPeriod, _tryAppReview);
  }

  void _queuePremiumAfterSuccess() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().currentUser?.id;
    final generation = ApiClient().sessionGeneration;
    final offerContext = PremiumOfferSuccessSignal.events.value.context;
    _premiumSuccessTimer?.cancel();
    // Give an eligible review opportunity priority over a second sales modal.
    final delay =
        _pendingReviewUserId == userId
            ? const Duration(seconds: 11)
            : const Duration(seconds: 2);
    _premiumSuccessTimer = Timer(delay, () {
      if (!mounted ||
          userId == null ||
          context.read<AuthProvider>().currentUser?.id != userId ||
          ApiClient().sessionGeneration != generation ||
          _currentIndex == 4 ||
          _currentIndex == 5)
        return;
      // maybeShow also checks active route, text entry and app lifecycle.
      // If the camera/form is still open, drop this optional prompt.
      ContextualPremiumOfferService.maybeShow(context, offerContext);
    });
  }

  bool _reviewIsSafe(String userId) {
    return mounted &&
        context.read<AuthProvider>().currentUser?.id == userId &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false) &&
        _currentIndex != 4 &&
        _currentIndex != 5 &&
        !ContextualPremiumOfferService.isPresenting &&
        !context.read<MealPlanProvider>().isGenerating &&
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorStateOfType<EditableTextState>() ==
            null &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
  }

  Future<void> _tryAppReview() async {
    final userId = _pendingReviewUserId;
    if (!mounted || userId == null) return;
    if (context.read<AuthProvider>().currentUser?.id != userId ||
        !_reviewSchedule.isReady(
          userId,
          ApiClient().sessionGeneration,
          DateTime.now(),
        ) ||
        _pendingReviewGeneration != ApiClient().sessionGeneration) {
      _pendingReviewUserId = null;
      return;
    }
    if (!_reviewIsSafe(userId)) {
      _reviewTimer = Timer(const Duration(seconds: 15), _tryAppReview);
      return;
    }
    _pendingReviewUserId = null;
    final requested = await _appReview.maybeRequest(
      stillSafe:
          () =>
              _pendingReviewGeneration == ApiClient().sessionGeneration &&
              _reviewIsSafe(userId),
    );
    if (requested) _premiumSuccessTimer?.cancel();
  }

  @override
  void dispose() {
    AppReviewSignal.successfulActions.removeListener(_queueAppReview);
    PremiumOfferSuccessSignal.events.removeListener(_queuePremiumAfterSuccess);
    _premiumSuccessTimer?.cancel();
    _reviewTimer?.cancel();
    super.dispose();
  }

  void _ensureTab(int index) {
    _tabs[index] ??= _createTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        // IndexedStack utrzymuje już odwiedzone zakładki w pamięci. Puste
        // miejsca pozostają lekkie, dopóki użytkownik nie otworzy danej
        // sekcji po raz pierwszy.
        body: IndexedStack(
          index: _currentIndex,
          children: List<Widget>.generate(
            _tabs.length,
            // IndexedStack retains hidden tabs, including their repeating
            // animations. Mute only their tickers while preserving tab State.
            (index) => TickerMode(
              enabled: index == _currentIndex,
              child: _tabs[index] ?? const SizedBox.shrink(),
            ),
          ),
        ),
        // Stały rozmiar eliminuje dodatkową animację położenia Scaffolda.
        // AnimatedSwitcher używa tej samej krzywej w obu kierunkach, więc
        // pojawianie jest dokładnym odwróceniem znikania.
        floatingActionButton: SizedBox(
          width: 116,
          height: 40,
          child: AnimatedSwitcher(
            duration:
                reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
            reverseDuration:
                reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder:
                (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .88, end: 1).animate(animation),
                    child: child,
                  ),
                ),
            child:
                (_currentIndex == 0 || _currentIndex == 4)
                    ? OutlinedButton.icon(
                      key: const ValueKey('quick-add-visible'),
                      onPressed: _showQuickAddSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        // Pełne, nieprzezroczyste tło: przycisk nie zlewa się
                        // z kartami znajdującymi się pod nim podczas przewijania.
                        backgroundColor:
                            AppTheme.isDark
                                ? const Color(0xFF173B35)
                                : const Color(0xFFE7F8F2),
                        side: BorderSide(
                          color: AppTheme.textSecondary.withValues(
                            alpha: AppTheme.isDark ? 0.9 : 0.72,
                          ),
                          width: 1.4,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(116, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text(
                        context.strings.add,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    )
                    : const SizedBox.shrink(key: ValueKey('quick-add-hidden')),
          ),
        ),
        floatingActionButtonLocation: const _QuickAddFabLocation(),
        bottomNavigationBar: Material(
          color:
              Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
              Theme.of(context).colorScheme.surface,
          elevation: 8,
          child: BottomNavigationBar(
            elevation: 0,
            // Sześć zakładek wymaga trybu 'fixed' — bez tego Flutter przechodzi
            // w tryb 'shifting' i rzuca wyjatek, co wywalalo aplikacje
            // zaraz po zakonczeniu onboardingu.
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 10,
            unselectedFontSize: 10,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            currentIndex: _currentIndex,
            onTap: (index) async {
              // UWAGA (nowe): "Śledzenie" (indeks 3) wymaga bramki reklamowej
              // dla kont bez Premium — patrz AdGateService (limit 2 reklamy
              // na 8 godzin, potem wolny dostęp aż do wygaśnięcia okna).
              // Premium pomija to całkowicie.
              // UWAGA (NAPRAWA AWARYJNA — TYMCZASOWE WYŁĄCZENIE): patrz
              // identyczny komentarz w main.dart. Cała bramka reklamowa
              // jest tymczasowo pominięta — Śledzenie wpuszcza teraz
              // wszystkich normalnie, bez żadnego kodu SDK reklam w grze,
              // dopóki nie zdiagnozujemy prawdziwej przyczyny awarii przy
              // starcie na podstawie logów.
              //
              // if (index == 3) {
              //   final hasPremium = Provider.of<AuthProvider>(context, listen: false)
              //       .currentUser
              //       ?.hasPremiumAccess ??
              //       false;
              //   if (!hasPremium) {
              //     final needsAd = await AdGateService().needsAd();
              //     if (needsAd) {
              //       if (!context.mounted) return;
              //       final watched = await Navigator.of(context).push<bool>(
              //         MaterialPageRoute(builder: (_) => const AdGateScreen()),
              //       );
              //       if (watched != true) {
              //         return;
              //       }
              //     }
              //   }
              // }
              if (!mounted) return;
              setState(() {
                _ensureTab(index);
                _currentIndex = index;
              });
            },
            items: [
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.home_outlined, active: false),
                activeIcon: _buildNavIcon(Icons.home, active: true),
                label: context.strings.home,
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.restaurant_outlined, active: false),
                activeIcon: _buildNavIcon(Icons.restaurant, active: true),
                label: context.strings.recipes,
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(
                  Icons.shopping_cart_outlined,
                  active: false,
                ),
                activeIcon: _buildNavIcon(Icons.shopping_cart, active: true),
                label: context.strings.shopping,
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(
                  Icons.local_fire_department_outlined,
                  active: false,
                ),
                activeIcon: _buildNavIcon(
                  Icons.local_fire_department,
                  active: true,
                ),
                label: context.strings.diary,
              ),
              // Zakładka Premium — bezpośredni dostęp do porównania planów i
              // zakupu subskrypcji, bez konieczności wchodzenia przez Profil.
              BottomNavigationBarItem(
                icon: _buildNavIcon(
                  Icons.workspace_premium_outlined,
                  active: false,
                ),
                activeIcon: _buildNavIcon(
                  Icons.workspace_premium,
                  active: true,
                ),
                label: context.strings.premium,
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.person_outline, active: false),
                activeIcon: _buildNavIcon(Icons.person, active: true),
                label: context.strings.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBatchScanner() async {
    final user = context.read<AuthProvider>().currentUser;
    if (!(user?.hasPremiumAccess ?? false)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const BatchBarcodeScannerScreen(previewOnly: true),
        ),
      );
      return;
    }

    final completed = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const BatchBarcodeScannerScreen()),
    );
    if (!mounted || completed == null || completed == 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.strings.homeBatchCompleted(completed))),
      );
  }

  void _showQuickAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder:
          (sheetContext) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheetContext.strings.whatToAdd,
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    _quickAddOption(
                      sheetContext,
                      icon: Icons.barcode_reader,
                      title: sheetContext.strings.scanProduct,
                      subtitle: sheetContext.strings.barcodeDestinations,
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await scanProductWithDestination(context);
                      },
                    ),
                    _quickAddOption(
                      sheetContext,
                      icon: Icons.qr_code_2,
                      title: sheetContext.strings.batchScan,
                      subtitle: sheetContext.strings.batchDestinationHint,
                      trailing: const PremiumFeatureTag(),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openBatchScanner();
                      },
                    ),
                    _quickAddOption(
                      sheetContext,
                      icon: Icons.auto_awesome,
                      title: sheetContext.strings.addRecipeWithAi,
                      subtitle: sheetContext.strings.aiRecipeSources,
                      trailing: PremiumFeatureTag(
                        label: sheetContext.strings.premiumTwoPoints,
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AiAddRecipeScreen(),
                          ),
                        );
                      },
                    ),
                    _quickAddOption(
                      sheetContext,
                      icon: Icons.restaurant_menu,
                      title: sheetContext.strings.addMeal,
                      subtitle: sheetContext.strings.recordCaloriesAndMacros,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).pushNamed('/tracker/add');
                      },
                    ),
                    _quickAddOption(
                      sheetContext,
                      icon: Icons.inventory_2_outlined,
                      title: sheetContext.strings.addToPantry,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => const PantryScreen(openAddOnStart: true),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _quickAddOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: AdaptiveActionTile(
          icon: icon,
          title: title,
          subtitle: subtitle,
          titleMaxLines: 2,
          subtitleMaxLines: 3,
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }

  /// Jednolita plakietka każdej pozycji dolnej nawigacji. Stały rozmiar
  /// zapobiega podskakiwaniu etykiet, a delikatne tło pokazuje bieżącą
  /// sekcję bez zmiany neutralnego, szarego koloru ikon.
  Widget _buildNavIcon(IconData icon, {required bool active}) {
    final colors = Theme.of(context).colorScheme;
    final iconColor =
        Theme.of(context).bottomNavigationBarTheme.unselectedItemColor ??
        colors.onSurfaceVariant;
    final background = Color.alphaBlend(
      colors.primary.withOpacity(
        active
            ? (Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.13)
            : (Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.07),
      ),
      colors.surface,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 21, color: iconColor),
      ),
    );
  }
}

/// Umieszcza wąski przycisk tuż nad dolną nawigacją bez tworzenia pod nim
/// pełnoszerokiego kontenera. Dzięki temu po bokach przycisku pozostaje
/// rzeczywista zawartość ekranu, a nie jasny pas.
class _QuickAddFabLocation extends FloatingActionButtonLocation {
  const _QuickAddFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final buttonSize = scaffoldGeometry.floatingActionButtonSize;
    final x = (scaffoldGeometry.scaffoldSize.width - buttonSize.width) / 2;
    const navigationGap = 12.0;
    const notificationGap = 10.0;
    final regularY =
        scaffoldGeometry.contentBottom - buttonSize.height - navigationGap;
    final notificationY =
        scaffoldGeometry.contentBottom -
        scaffoldGeometry.snackBarSize.height -
        buttonSize.height -
        notificationGap;
    final y =
        scaffoldGeometry.snackBarSize.height > 0 ? notificationY : regularY;
    return Offset(x, y);
  }
}

// --- WIDGET ZAKŁADKI START ---
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  // Pomocnicza metoda do obliczania bieżącego dnia planu na podstawie daty startowej
  int _getCurrentPlanDay(MealPlan plan) {
    return plan.dayNumberAt(DateTime.now()) ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final mealPlanProvider = Provider.of<MealPlanProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final foodLogProvider = Provider.of<FoodLogProvider>(context);

    final user = authProvider.currentUser;
    // currentPlan respektuje ręczny wybór z przełącznika planów (patrz
    // MealPlanProvider.selectPlan) — activePlan zawsze zwraca pierwszy
    // znaleziony, co uniemożliwiłoby przełączanie się między kilkoma
    // aktywnymi planami.
    final selectedPlan = mealPlanProvider.currentPlan;
    final activePlan =
        selectedPlan?.isInUseAt(DateTime.now()) == true
            ? selectedPlan
            : mealPlanProvider.activePlan;
    final currentDay = activePlan != null ? _getCurrentPlanDay(activePlan) : 1;

    // Pobierz nazwę sklepu z ID
    String getStoreName(String id) {
      try {
        return storeProvider.stores.firstWhere((s) => s.id == id).name;
      } catch (_) {
        return context.strings.homeShopFallback;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          const DecorativeCircles(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  mealPlanProvider.loadPlans(),
                  foodLogProvider.fetchLogsForDate(DateTime.now()),
                  Provider.of<WellnessProvider>(
                    context,
                    listen: false,
                  ).loadForDate(DateTime.now()),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Powitanie
                    Row(
                      children: [
                        Image.asset(
                          'assets/branding/logo.png',
                          width: 44,
                          height: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // UWAGA (naprawa): wcześniej odznaka Premium
                              // dzieliła jeden, wąski rząd z nickiem (obok
                              // logo, dzwoneczka i awatara po drugiej stronie)
                              // — przy dłuższym imieniu odznaka "wygryzała"
                              // większość tekstu powitania, sprawiając wrażenie,
                              // że nick jest przez nią zasłonięty. Teraz
                              // powitanie ma pełną szerokość dla siebie, a
                              // odznaka jest na osobnej linii pod spodem.
                              Text(
                                context.strings.homeGreeting(
                                  user?.displayName ??
                                      context.strings.homeUserFallback,
                                ),
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (user?.hasPremiumAccess ?? false) ...[
                                const SizedBox(height: 4),
                                const PremiumBadge(fontSize: 9),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                context.strings.homeCookingToday,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        // Dzwoneczek powiadomień — z odznaką liczby
                        // nieprzeczytanych. Na razie tylko wewnątrz aplikacji
                        // (bez powiadomień systemowych/push, które wymagają
                        // Firebase Cloud Messaging).
                        const NotificationBell(),
                        const SizedBox(width: 4),
                        // Szybki skrót do profilu
                        GestureDetector(
                          onTap:
                              () => Navigator.of(context).pushNamed('/profile'),
                          child: UserAvatar(
                            avatar: user?.avatar,
                            avatarPhotoBase64: user?.avatarPhotoBase64,
                            size: 48,
                          ),
                        ),
                      ],
                    ).animate().fadeIn().slideY(begin: -0.1, end: 0),
                    const SizedBox(height: 24),

                    // Najczęstsze wejścia są pierwsze i mieszczą się w równej
                    // siatce 2x2. Przepisy są już w dolnym menu, więc nie
                    // dublujemy tutaj tego samego odnośnika.
                    Text(
                      context.strings.homeQuickActions,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      // Nie ściskamy kafelków do jednego wiersza. Na węższych
                      // telefonach i przy większym rozmiarze tekstu tytuły
                      // (np. „Baza produktów”) mogą dzięki temu ułożyć się w
                      // dwóch pełnych wierszach zamiast kończyć wielokropkiem.
                      childAspectRatio:
                          MediaQuery.sizeOf(context).width < 370 ? 1.55 : 1.75,
                      children: [
                        _buildQuickActionCard(
                          context,
                          title: context.strings.newPlan,
                          subtitle: context.strings.planMeals,
                          icon: Icons.calendar_today_outlined,
                          color: AppTheme.primaryColor,
                          onTap:
                              () => Navigator.of(
                                context,
                              ).pushNamed('/plan/config'),
                        ),
                        _buildQuickActionCard(
                          context,
                          title: context.strings.productDatabase,
                          subtitle: context.strings.checkPrices,
                          icon: Icons.storefront_outlined,
                          color: AppTheme.accentColor,
                          onTap:
                              () =>
                                  Navigator.of(context).pushNamed('/products'),
                        ),
                        _buildQuickActionCard(
                          context,
                          title: context.strings.promotions,
                          subtitle: context.strings.currentOffers,
                          icon: Icons.local_offer_outlined,
                          color: Colors.red,
                          onTap:
                              () => Navigator.of(
                                context,
                              ).pushNamed('/promotions'),
                        ),
                        _buildQuickActionCard(
                          context,
                          title: context.strings.pantry,
                          subtitle: context.strings.whatYouHaveAtHome,
                          icon: Icons.inventory_2_outlined,
                          color: AppTheme.secondaryColor,
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PantryScreen(),
                                ),
                              ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                    const _ContextualPremiumCard(),
                    const SizedBox(height: 24),

                    // Dopiero po skrótach pokazujemy postęp bieżącego dnia.
                    _buildDailySummaryCard(context, foodLogProvider),
                    const SizedBox(height: 24),

                    // Aktywny Plan Posiłków
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed:
                            () => Navigator.of(
                              context,
                            ).pushNamed('/plan/archive'),
                        icon: const Icon(Icons.inventory_2_outlined, size: 18),
                        label: Text(context.strings.planArchive),
                      ),
                    ),
                    if ((!mealPlanProvider.hasLoaded ||
                            mealPlanProvider.isLoading) &&
                        mealPlanProvider.plans.isEmpty)
                      _buildDataStateCard(
                        context,
                        message: context.strings.homePlanLoading,
                        loading: true,
                      )
                    else if (mealPlanProvider.errorMessage != null &&
                        mealPlanProvider.plans.isEmpty)
                      _buildDataStateCard(
                        context,
                        message: context.strings.homePlanLoadError,
                        onRetry: mealPlanProvider.loadPlans,
                      )
                    else if (activePlan != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              activePlan.startsAfter(DateTime.now())
                                  ? context.strings.homeNextPlan
                                  : context.strings.homeActivePlan,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/plan/view');
                            },
                            child: Text(context.strings.homeDetails),
                          ),
                        ],
                      ),
                      // Plany z różnych tygodni mogą współistnieć również
                      // na koncie standardowym. Przełącznik pojawia się,
                      // gdy użytkownik ma więcej niż jeden aktywny plan.
                      if (mealPlanProvider.activePlans.length > 1) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: mealPlanProvider.activePlans.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final plan = mealPlanProvider.activePlans[index];
                              final isSelected = plan.id == activePlan.id;
                              return ChoiceChip(
                                label: Text(
                                  context.strings.homePlanChip(
                                    plan.createdAt.toLocal().day,
                                    plan.createdAt.toLocal().month,
                                    plan.durationDays,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected:
                                    (_) => mealPlanProvider.selectPlan(plan),
                                selectedColor: AppTheme.actionPrimaryColor,
                                labelStyle: TextStyle(
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                          : AppTheme.textPrimary,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _buildActivePlanCard(
                        context,
                        plan: activePlan,
                        storeName: getStoreName(activePlan.storeId),
                        currentDay: currentDay,
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 12),
                      if (activePlan.dayNumberAt(DateTime.now()) != null)
                        ...activePlan.entriesForDay(currentDay).map((entry) {
                          return _buildMealItem(context, entry);
                        }).toList(),
                    ] else ...[
                      // Brak aktywnego planu - pusta sekcja zachęcająca do stworzenia
                      _buildNoPlanCard(context).animate().fadeIn(delay: 200.ms),
                    ],
                    const SizedBox(height: 24),

                    // Treści dodatkowe są na końcu — nie odsuwają planu ani
                    // dzisiejszych posiłków od początku ekranu.
                    _buildContestBanner(context),
                    const SizedBox(height: 12),
                    _buildTipOfTheDayCard(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Podsumowanie dnia — jeden duży pasek kcal (spożyte/cel) i trzy
  /// mniejsze dla makroskładników. Cel makro liczony tym samym,
  /// standardowym podziałem co w kalkulatorze kalorii (25% białko /
  /// 30% tłuszcz / 45% węglowodany) z targetCalories — spójne z tym,
  /// co użytkownik widzi w kalkulatorze.
  Widget _buildDailySummaryCard(
    BuildContext context,
    FoodLogProvider foodLogProvider,
  ) {
    final summary = foodLogProvider.summary;

    if (foodLogProvider.isLoading ||
        (summary == null && foodLogProvider.error == null)) {
      return _buildDataStateCard(
        context,
        message: context.strings.homeNutritionLoading,
        loading: true,
      );
    }
    if (foodLogProvider.error != null && summary == null) {
      return _buildDataStateCard(
        context,
        message: context.strings.homeNutritionError,
        onRetry: () => foodLogProvider.fetchLogsForDate(DateTime.now()),
      );
    }

    // Wartość 0 pokazujemy dopiero po prawidłowym pobraniu podsumowania.
    // Brak odpowiedzi serwera ma osobny stan powyżej.
    final consumedKcal = summary!.totalCalories;
    final targetKcal = summary.targetCalories;
    final consumedProtein = summary.totalProtein;
    final consumedFat = summary.totalFat;
    final consumedCarbs = summary.totalCarbs;

    final targetProtein = targetKcal * 0.25 / 4;
    final targetFat = targetKcal * 0.30 / 9;
    final targetCarbs = targetKcal * 0.45 / 4;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.strings.homeEatenToday,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${consumedKcal.round()} / ${targetKcal.round()} kcal',
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildProgressBar(
            consumedKcal,
            targetKcal,
            AppTheme.primaryColor,
            height: 10,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMacroBar(
                  context,
                  context.strings.homeProtein,
                  consumedProtein,
                  targetProtein,
                  AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroBar(
                  context,
                  context.strings.homeFat,
                  consumedFat,
                  targetFat,
                  const Color(0xFFE0A62E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMacroBar(
                  context,
                  context.strings.homeCarbsShort,
                  consumedCarbs,
                  targetCarbs,
                  const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Nawodnienie w sekcji "Dziś zjedzono", pod makroskładnikami —
          // to element tego samego podsumowania dnia co kalorie i makro,
          // więc jego miejsce jest tutaj, a nie osobno wyżej na ekranie.
          _buildWaterStrip(context),
        ],
      ),
    );
  }

  Widget _buildDataStateCard(
    BuildContext context, {
    required String message,
    bool loading = false,
    Future<void> Function()? onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(Icons.cloud_off_outlined, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          if (onRetry != null)
            IconButton(
              tooltip: context.strings.homeRetry,
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }

  /// Wspólny wygląd kafelka-odnośnika: ikona w kolorowym kwadracie,
  /// tytuł, podpis i strzałka. Jeden widget dla nawodnienia i kalkulatora,
  /// żeby oba wyglądały identycznie — wcześniej każdy miał własny układ.
  Widget _buildTileLink(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppTheme.surfaceColor,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(
    BuildContext context,
    String label,
    double consumed,
    double target,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          '${consumed.round()}g',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        _buildProgressBar(consumed, target, color, height: 6),
      ],
    );
  }

  Widget _buildProgressBar(
    double consumed,
    double target,
    Color color, {
    double height = 8,
  }) {
    final ratio = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: height,
        backgroundColor: color.withOpacity(0.15),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  /// Kompaktowa karta z jedną, rotującą poradą kulinarną — zmienia się
  /// raz dziennie (deterministycznie wg dnia roku, nie losowo przy
  /// każdym odświeżeniu ekranu). Dotknięcie otwiera pełną listę.
  Widget _buildTipOfTheDayCard(BuildContext context) {
    final now = DateTime.now();
    final tips = cookingTipsFor(context.strings.localeName);
    final tipIndex = cookingTipIndexForDate(now);
    final tip = tips[tipIndex];

    return GestureDetector(
      // Przekazujemy indeks porady dnia, żeby lista otworzyła się na NIEJ,
      // a nie na początku. Dotąd użytkownik czytał poradę na ekranie
      // głównym, dotykał jej i lądował na górze listy kilkudziesięciu
      // pozycji, gdzie musiał jej szukać.
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CookingTipsScreen(highlightIndex: tipIndex),
            ),
          ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.secondaryColor.withOpacity(0.15),
              AppTheme.primaryColor.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lightbulb_outline,
              color: AppTheme.secondaryColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.homeTipOfTheDay,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tip.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tip.tip,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Baner cotygodniowego konkursu na liczbę opublikowanych przepisów.
  /// Nagrody (3/2/1 punkt premium za miejsca 1–3) odpowiadają
  /// _PLACE_POINTS w backend/app/services/weekly_contest.py — jeśli tam
  /// się zmienią, trzeba poprawić też ten tekst.
  /// Wąski pasek nawodnienia na ekranie startowym — sam podgląd postępu,
  /// bez przycisków dolewania. Dodawanie zostaje w zakładce Śledzenie,
  /// żeby nie dublować tej samej funkcji w dwóch miejscach; tutaj chodzi
  /// wyłącznie o to, żeby stan dnia był widoczny od razu po otwarciu.
  /// Nawodnienie — ten SAM wygląd co kafelek kalkulatora (wspólny
  /// _buildTileLink), żeby oba elementy na ekranie startowym wyglądały
  /// jednolicie. Zamiast strzałki po prawej pokazujemy postęp w kółku,
  /// bo to najważniejsza informacja tego kafelka.
  Widget _buildWaterStrip(BuildContext context) {
    final wellness = Provider.of<WellnessProvider>(context);
    const waterBlue = Color(0xFF3B9AE1);

    if (!wellness.hasLoaded || wellness.isLoading) {
      return _buildTileLink(
        context,
        icon: Icons.water_drop,
        color: waterBlue,
        title: context.strings.homeHydration,
        subtitle: context.strings.homeDataLoading,
        onTap: () {},
        trailing: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (wellness.errorMessage != null) {
      return _buildTileLink(
        context,
        icon: Icons.water_drop,
        color: waterBlue,
        title: context.strings.homeHydration,
        subtitle: context.strings.homeDataError,
        onTap: () => wellness.loadForDate(DateTime.now()),
        trailing: const Icon(Icons.refresh, color: waterBlue),
      );
    }

    final ml = wellness.data.waterMl;
    final goal = wellness.data.waterGoalMl;
    final progress = goal > 0 ? (ml / goal).clamp(0.0, 1.0) : 0.0;

    return _buildTileLink(
      context,
      icon: Icons.water_drop,
      color: waterBlue,
      title: context.strings.homeHydration,
      subtitle: context.strings.homeWaterProgress(
        ml,
        goal,
        (progress * 100).round(),
      ),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CalorieTrackerScreen()),
          ),
      trailing: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: waterBlue.withOpacity(0.15),
              color: waterBlue,
            ),
            Text(
              '${(progress * 100).round()}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: waterBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContestBanner(BuildContext context) {
    const gold = Color(0xFFE0A62E);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecipeLeaderboardScreen()),
          ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [gold.withOpacity(0.18), gold.withOpacity(0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: gold.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events, color: gold, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.strings.homeWeeklyContest,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.strings.homeWeeklyContestHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: gold.withOpacity(0.8)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 80.ms);
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    // UWAGA (naprawa): przebudowane z pionowej karty (ikona nad tekstem)
    // na poziomy, kompaktowy układ (ikona obok tekstu) — pasuje do
    // nowej siatki 2x2 zamiast poprzedniej, szerokiej listy przewijanej
    // w bok.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.fade,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.fade,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePlanCard(
    BuildContext context, {
    required MealPlan plan,
    required String storeName,
    required int currentDay,
  }) {
    final upcoming = plan.startsAfter(DateTime.now());
    final progress = upcoming ? 0.0 : currentDay / plan.durationDays;
    final start = DateTime.tryParse(plan.startDate ?? '');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        storeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  context.strings.planStatusLabel(plan.status).toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            upcoming && start != null
                ? context.strings.homePlanStarts(
                  '${start.day.toString().padLeft(2, '0')}${context.strings.localeName.startsWith('en') ? '/' : '.'}'
                  '${start.month.toString().padLeft(2, '0')}${context.strings.localeName.startsWith('en') ? '/' : '.'}${start.year}',
                )
                : context.strings.homePlanDay(currentDay, plan.durationDays),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.backgroundColor,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/plan/view');
                  },
                  child: Text(context.strings.homeViewPlan),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Przejdź do zakupów
                    Navigator.of(context).pushNamed('/shopping');
                  },
                  child: Text(context.strings.shopping),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealItem(BuildContext context, MealPlanEntry entry) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/recipe/detail', arguments: entry);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: RecipePhoto(
                recipe: entry.recipe,
                borderRadius: BorderRadius.circular(8),
                showAiBadge: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.mealTypeLabel(entry.mealSlot).toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.primaryColor.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.recipe.displayName(context),
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPlanCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            context.strings.homeNoPlan,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.strings.homeNoPlanHint,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/plan/config'),
            child: Text(context.strings.homeCreatePlan),
          ),
        ],
      ),
    );
  }
}

class _ContextualPremiumCard extends StatefulWidget {
  const _ContextualPremiumCard();

  @override
  State<_ContextualPremiumCard> createState() => _ContextualPremiumCardState();
}

class _ContextualPremiumCardState extends State<_ContextualPremiumCard> {
  int _scanCount = 0;
  Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _scanCount = prefs.getInt('successful_barcode_scans') ?? 0;
      _dismissed =
          prefs.getStringList('dismissed_premium_hints')?.toSet() ?? {};
    });
  }

  Future<void> _dismiss(String key) async {
    final prefs = await SharedPreferences.getInstance();
    _dismissed.add(key);
    await prefs.setStringList('dismissed_premium_hints', _dismissed.toList());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final plans = context.watch<MealPlanProvider>().plans;
    if (user == null || user.hasPremiumAccess) return const SizedBox.shrink();

    late final String key;
    late final IconData icon;
    late final String title;
    late final String text;
    late final String action;
    late final VoidCallback onTap;

    if (user.premiumPoints >= 2 && !_dismissed.contains('free_ai')) {
      key = 'free_ai';
      icon = Icons.auto_awesome;
      title = context.strings.homeAiPointsTitle;
      text = context.strings.homeAiPointsHint;
      action = context.strings.homeTryAction;
      onTap =
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AiAddRecipeScreen()));
    } else if (_scanCount >= 2 && !_dismissed.contains('batch_scan')) {
      key = 'batch_scan';
      icon = Icons.qr_code_scanner;
      title = context.strings.homeBatchTitle;
      text = context.strings.homeBatchHint;
      action = context.strings.homeViewPremium;
      onTap =
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
    } else if (plans.isNotEmpty && !_dismissed.contains('auto_week')) {
      key = 'auto_week';
      icon = Icons.auto_mode_outlined;
      title = context.strings.homeAutoWeekTitle;
      text = context.strings.homeAutoWeekHint;
      action = context.strings.homeCheckAction;
      onTap =
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppTheme.secondaryColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(icon, color: AppTheme.actionSecondaryColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 34),
                    ),
                    child: Text(action),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.strings.homeHideHint,
              onPressed: () => _dismiss(key),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
