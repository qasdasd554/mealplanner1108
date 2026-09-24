import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
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
import '../ads/ad_gate_screen.dart';
import '../../services/ad_gate_service.dart';
import '../../data/cooking_tips.dart';
import 'cooking_tips_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 5) as int;
    // Pobierz plany posiłków na start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MealPlanProvider>(context, listen: false).loadPlans();
      Provider.of<StoreProvider>(context, listen: false).loadStores();
      // Podsumowanie dnia (kcal/makro) na ekranie głównym — bez tego
      // FoodLogProvider.summary zostawałby null, dopóki użytkownik nie
      // odwiedziłby osobno ekranu Śledzenia.
      Provider.of<FoodLogProvider>(context, listen: false).fetchLogsForDate(DateTime.now());
      // Nawodnienie na pasku ekranu startowego — z tego samego powodu co
      // wyżej: bez tego pasek pokazywałby 0 ml, dopóki użytkownik nie
      // wszedłby osobno w zakładkę Śledzenie.
      Provider.of<WellnessProvider>(context, listen: false).loadForDate(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    // Podział na taby
    // UWAGA (zmiana): kolejność "Śledzenie" i "Profil" zamieniona miejscami
    // na życzenie — Śledzenie (częściej używana funkcja) jest teraz na
    // czwartej pozycji, Profil na piątej.
    final List<Widget> tabs = [
      const HomeTab(),
      const RecipesScreen(),
      const ShoppingListScreen(isTab: true),
      const CalorieTrackerScreen(),
      const PremiumScreen(popAfterSuccess: false),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: tabs[_currentIndex],
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentIndex == 0 || _currentIndex == 4)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: SizedBox(
                  width: 116,
                  height: 34,
                  child: FilledButton.tonalIcon(
                    onPressed: _showQuickAddSheet,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(116, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Dodaj'),
                  ),
                ),
              ),
            Material(
              color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
                  Theme.of(context).colorScheme.surface,
              elevation: 8,
              child: BottomNavigationBar(
                elevation: 0,
        // 5 zakladek wymaga trybu 'fixed' — bez tego Flutter przechodzi
        // w tryb 'shifting' i rzuca wyjatek, co wywalalo aplikacje
        // zaraz po zakonczeniu onboardingu.
                type: BottomNavigationBarType.fixed,
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
            _currentIndex = index;
          });
                },
                items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Start',
          ),
          // "Przepisy" ma teraz tę samą kolorową plakietkę co "Zakupy" i
          // "Śledzenie" — spójne wizualne wyróżnienie głównych funkcji.
          BottomNavigationBarItem(
            icon: _buildHighlightedIcon(Icons.restaurant_outlined, active: false),
            activeIcon: _buildHighlightedIcon(Icons.restaurant, active: true),
            label: 'Przepisy',
          ),
          BottomNavigationBarItem(
            icon: _buildHighlightedIcon(Icons.shopping_cart_outlined, active: false),
            activeIcon: _buildHighlightedIcon(Icons.shopping_cart, active: true),
            label: 'Zakupy',
          ),
          BottomNavigationBarItem(
            icon: _buildHighlightedIcon(Icons.local_fire_department_outlined, active: false),
            activeIcon: _buildHighlightedIcon(Icons.local_fire_department, active: true),
            label: 'Śledzenie',
          ),
          // Zakładka Premium — bezpośredni dostęp do porównania planów i
          // zakupu subskrypcji, bez konieczności wchodzenia przez Profil.
          const BottomNavigationBarItem(
            icon: Icon(Icons.workspace_premium_outlined),
            activeIcon: Icon(Icons.workspace_premium),
            label: 'Premium',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBatchScanner() async {
    final user = context.read<AuthProvider>().currentUser;
    if (!(user?.hasPremiumAccess ?? false)) {
      final openPremium = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Skanowanie seryjne jest w Premium'),
          content: const Text(
            'Aparat pozostaje otwarty, a kolejne produkty są automatycznie '
            'dodawane do spiżarni. Każdy wynik możesz też przekazać do '
            'śledzenia albo bazy produktów.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Nie teraz'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Zobacz Premium'),
            ),
          ],
        ),
      );
      if (openPremium == true && mounted) {
        setState(() => _currentIndex = 4);
      }
      return;
    }

    final added = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const BatchBarcodeScannerScreen()),
    );
    if (!mounted || added == null || added == 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Dodano do spiżarni: $added produktów.'),
      ));
  }

  void _showQuickAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Co chcesz dodać?',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.barcode_reader),
                title: const Text('Zeskanuj produkt'),
                subtitle: const Text(
                  'Dodaj do śledzenia, bazy produktów albo spiżarni',
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await scanProductWithDestination(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: const Text('Skanuj seryjnie do spiżarni'),
                subtitle: const Text(
                  'Wiele produktów; także śledzenie i baza produktów',
                ),
                trailing: const PremiumFeatureTag(),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openBatchScanner();
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text('Dodaj przepis z AI'),
                subtitle: const Text('Ze zdjęcia, tekstu albo linku'),
                trailing: const PremiumFeatureTag(label: 'PREMIUM / 2 PKT'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AiAddRecipeScreen(),
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: const Text('Dodaj posiłek'),
                subtitle: const Text('Zapisz kalorie i makroskładniki'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).pushNamed('/tracker/add');
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Dodaj do spiżarni'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PantryScreen(openAddOnStart: true),
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ikona z kolorową plakietką w tle — używana dla \"Zakupy\" i \"Śledzenie\",
  /// dwóch najważniejszych funkcji aplikacji, żeby wizualnie wyróżniały się
  /// na tle pozostałych, zwykłych zakładek nawigacji.
  Widget _buildHighlightedIcon(IconData icon, {required bool active}) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.primaryColor.withOpacity(0.15)
            : AppTheme.primaryColor.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: active ? 26 : 24),
    );
  }
}

// --- WIDGET ZAKŁADKI START ---
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  // Pomocnicza metoda do obliczania bieżącego dnia planu na podstawie daty startowej
  int _getCurrentPlanDay(MealPlan plan) {
    if (plan.startDate == null) return 1;
    try {
      final start = DateTime.parse(plan.startDate!);
      final today = DateTime.now();
      final difference = today.difference(start).inDays + 1;
      if (difference < 1) return 1;
      if (difference > plan.durationDays) return plan.durationDays;
      return difference;
    } catch (_) {
      return 1;
    }
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
    final activePlan = mealPlanProvider.currentPlan ?? mealPlanProvider.activePlan;
    final currentDay = activePlan != null ? _getCurrentPlanDay(activePlan) : 1;

    // Pobierz nazwę sklepu z ID
    String getStoreName(String id) {
      try {
        return storeProvider.stores.firstWhere((s) => s.id == id).name;
      } catch (_) {
        return 'Sklep';
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
                  Provider.of<WellnessProvider>(context, listen: false)
                      .loadForDate(DateTime.now()),
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
                            'Cześć, ${user?.displayName ?? 'użytkowniku'}!',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (user?.hasPremiumAccess ?? false) ...[
                            const SizedBox(height: 4),
                            const PremiumBadge(fontSize: 9),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Co dziś gotujemy?',
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
                      onTap: () => Navigator.of(context).pushNamed('/profile'),
                      child: UserAvatar(avatar: user?.avatar, avatarPhotoBase64: user?.avatarPhotoBase64, size: 48),
                    ),
                  ],
                ).animate().fadeIn().slideY(begin: -0.1, end: 0),
                const SizedBox(height: 24),

                // Najczęstsze wejścia są pierwsze i mieszczą się w równej
                // siatce 2x2. Przepisy są już w dolnym menu, więc nie
                // dublujemy tutaj tego samego odnośnika.
                Text(
                  'Szybkie akcje',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                      title: 'Nowy plan',
                      subtitle: 'Zaplanuj posiłki',
                      icon: Icons.calendar_today_outlined,
                      color: AppTheme.primaryColor,
                      onTap: () => Navigator.of(context).pushNamed('/plan/config'),
                    ),
                    _buildQuickActionCard(
                      context,
                      title: 'Baza produktów',
                      subtitle: 'Sprawdź ceny',
                      icon: Icons.storefront_outlined,
                      color: AppTheme.accentColor,
                      onTap: () => Navigator.of(context).pushNamed('/products'),
                    ),
                    _buildQuickActionCard(
                      context,
                      title: 'Promocje',
                      subtitle: 'Aktualne okazje',
                      icon: Icons.local_offer_outlined,
                      color: Colors.red,
                      onTap: () => Navigator.of(context).pushNamed('/promotions'),
                    ),
                    _buildQuickActionCard(
                      context,
                      title: 'Spiżarnia',
                      subtitle: 'Co masz w domu',
                      icon: Icons.inventory_2_outlined,
                      color: AppTheme.secondaryColor,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PantryScreen()),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 24),

                // Dopiero po skrótach pokazujemy postęp bieżącego dnia.
                _buildDailySummaryCard(context, foodLogProvider),
                const SizedBox(height: 24),

                // Aktywny Plan Posiłków
                if ((!mealPlanProvider.hasLoaded || mealPlanProvider.isLoading) &&
                    mealPlanProvider.plans.isEmpty)
                  _buildDataStateCard(
                    context,
                    message: 'Wczytywanie planu posiłków…',
                    loading: true,
                  )
                else if (mealPlanProvider.errorMessage != null &&
                    mealPlanProvider.plans.isEmpty)
                  _buildDataStateCard(
                    context,
                    message: 'Nie udało się wczytać planu posiłków.',
                    onRetry: mealPlanProvider.loadPlans,
                  )
                else if (activePlan != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Twój aktywny plan',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/plan/view');
                        },
                        child: const Text('Szczegóły'),
                      ),
                    ],
                  ),
                  // Plany z różnych tygodni mogą współistnieć również
                  // na koncie standardowym. Przełącznik pojawia się,
                  // gdy użytkownik ma więcej niż jeden aktywny plan.
                  if (mealPlanProvider.activePlans.length > 1) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: mealPlanProvider.activePlans.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final plan = mealPlanProvider.activePlans[index];
                          final isSelected = plan.id == activePlan.id;
                          return ChoiceChip(
                            label: Text(
                              'Plan ${plan.createdAt.toLocal().day}.${plan.createdAt.toLocal().month} '
                              '· ${plan.durationDays} dni',
                            ),
                            selected: isSelected,
                            onSelected: (_) => mealPlanProvider.selectPlan(plan),
                            selectedColor: AppTheme.actionPrimaryColor,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
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
  Widget _buildDailySummaryCard(BuildContext context, FoodLogProvider foodLogProvider) {
    final summary = foodLogProvider.summary;

    if (foodLogProvider.isLoading ||
        (summary == null && foodLogProvider.error == null)) {
      return _buildDataStateCard(
        context,
        message: 'Wczytywanie kalorii i makroskładników…',
        loading: true,
      );
    }
    if (foodLogProvider.error != null && summary == null) {
      return _buildDataStateCard(
        context,
        message: 'Nie udało się wczytać kalorii i makroskładników.',
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dziś zjedzono', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(
                '${consumedKcal.round()} / ${targetKcal.round()} kcal',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildProgressBar(consumedKcal, targetKcal, AppTheme.primaryColor, height: 10),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMacroBar(context, 'Białko', consumedProtein, targetProtein, AppTheme.secondaryColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildMacroBar(context, 'Tłuszcz', consumedFat, targetFat, const Color(0xFFE0A62E))),
              const SizedBox(width: 12),
              Expanded(child: _buildMacroBar(context, 'Węgl.', consumedCarbs, targetCarbs, const Color(0xFF3B82F6))),
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
              tooltip: 'Spróbuj ponownie',
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
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ?? Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(BuildContext context, String label, double consumed, double target, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text('${consumed.round()}g', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        const SizedBox(height: 4),
        _buildProgressBar(consumed, target, color, height: 6),
      ],
    );
  }

  Widget _buildProgressBar(double consumed, double target, Color color, {double height = 8}) {
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
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final tipIndex = dayOfYear % kCookingTips.length;
    final tip = kCookingTips[tipIndex];

    return GestureDetector(
      // Przekazujemy indeks porady dnia, żeby lista otworzyła się na NIEJ,
      // a nie na początku. Dotąd użytkownik czytał poradę na ekranie
      // głównym, dotykał jej i lądował na górze listy kilkudziesięciu
      // pozycji, gdzie musiał jej szukać.
      onTap: () => Navigator.of(context).push(
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
            const Icon(Icons.lightbulb_outline, color: AppTheme.secondaryColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PORADA DNIA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(tip.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    tip.tip,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
        title: 'Nawodnienie',
        subtitle: 'Wczytywanie danych…',
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
        title: 'Nawodnienie',
        subtitle: 'Nie udało się wczytać danych',
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
      title: 'Nawodnienie',
      subtitle: '$ml z $goal ml · ${(progress * 100).round()}% celu',
      onTap: () => Navigator.of(context).push(
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
                  fontSize: 9, fontWeight: FontWeight.bold, color: waterBlue),
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
      onTap: () => Navigator.of(context).push(
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
                  const Text(
                    'Konkurs tygodnia',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Dodaj najwięcej przepisów w tym tygodniu i zgarnij '
                    'punkty premium — 3 za 1. miejsce, 2 za 2., 1 za 3.',
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.fade,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
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
    final progress = currentDay / plan.durationDays;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    storeName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  plan.status.toUpperCase(),
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
            'Dzień $currentDay z ${plan.durationDays}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.backgroundColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                  child: const Text('Zobacz plan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Przejdź do zakupów
                    Navigator.of(context).pushNamed('/shopping');
                  },
                  child: const Text('Zakupy'),
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
        Navigator.of(context).pushNamed(
          '/recipe/detail',
          arguments: entry.recipe,
        );
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
                    entry.mealSlot.toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.primaryColor.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.recipe.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 16,
                        ),
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
            'Brak aktywnego planu posiłków',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Wygeneruj zbilansowany plan posiłków, zminimalizuj koszty i wygeneruj inteligentną listę zakupów.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/plan/config'),
            child: const Text('Stwórz nowy plan posiłków'),
          ),
        ],
      ),
    );
  }
}
