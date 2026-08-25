import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/user_avatar.dart';
import '../../models/meal_plan.dart';
import '../recipes/recipes_screen.dart';
import '../recipes/pantry_screen.dart';
import '../shopping/shopping_list_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/premium_screen.dart';
import '../tracker/calorie_tracker_screen.dart';
import '../ads/ad_gate_screen.dart';
import '../../services/ad_gate_service.dart';
import '../../data/cooking_tips.dart';
import 'cooking_tips_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Pobierz plany posiłków na start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MealPlanProvider>(context, listen: false).loadPlans();
      Provider.of<StoreProvider>(context, listen: false).loadStores();
      // Podsumowanie dnia (kcal/makro) na ekranie głównym — bez tego
      // FoodLogProvider.summary zostawałby null, dopóki użytkownik nie
      // odwiedziłby osobno ekranu Śledzenia.
      Provider.of<FoodLogProvider>(context, listen: false).fetchLogsForDate(DateTime.now());
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
      const PremiumScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
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
    // aktywnymi planami (funkcja premium).
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await mealPlanProvider.loadPlans();
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
                      child: UserAvatar(avatar: user?.avatar, size: 48),
                    ),
                  ],
                ).animate().fadeIn().slideY(begin: -0.1, end: 0),
                const SizedBox(height: 24),

                // Podsumowanie dnia (kcal + makro) — pokazuje od razu na
                // ekranie głównym, ile dziś zjedzono, bez konieczności
                // wchodzenia w Śledzenie. Styl pasków postępu podobny do
                // popularnych aplikacji (np. Fitatu) — jeden duży pasek
                // kcal na górze, trzy mniejsze dla makroskładników.
                _buildDailySummaryCard(context, foodLogProvider),
                const SizedBox(height: 24),

                // Skróty Szybkich Akcji — siatka 2x2 zamiast poziomo
                // przewijanej listy. UWAGA (naprawa): poprzednia wersja
                // (H-scroll) sprawiała, że 2 z 4 akcji były niewidoczne
                // bez przewinięcia w bok, więc użytkownik mógł ich nie
                // zauważyć w ogóle. Teraz wszystkie 4 widoczne od razu,
                // w mniejszych, bardziej kompaktowych kafelkach.
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
                  childAspectRatio: 2.2,
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
                      title: 'Przepisy',
                      subtitle: 'Szukaj inspiracji',
                      icon: Icons.menu_book_outlined,
                      color: AppTheme.secondaryColor,
                      onTap: () => Navigator.of(context).pushNamed('/recipes'),
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

                // Porada dnia — kompaktowa karta z jednym, rotującym
                // trikiem kulinarnym. Deterministyczna na podstawie dnia
                // roku (nie losowa przy każdym odświeżeniu), więc jest ta
                // sama przez cały dzień, ale zmienia się jutro.
                _buildTipOfTheDayCard(context),
                const SizedBox(height: 32),

                // Aktywny Plan Posiłków
                if (activePlan != null) ...[
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
                  // Przełącznik między kilkoma aktywnymi planami naraz —
                  // funkcja Premium. Widoczny TYLKO gdy faktycznie jest
                  // więcej niż jeden aktywny plan (darmowe konta mają
                  // zawsze co najwyżej jeden, więc dla nich ten rząd
                  // nigdy się nie pojawi).
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
                            label: Text('Plan ${plan.durationDays} dni'),
                            selected: isSelected,
                            onSelected: (_) => mealPlanProvider.selectPlan(plan),
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : null,
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
                  const SizedBox(height: 32),

                  // Dzisiejsze Posiłki
                  Text(
                    'Dzisiejsze posiłki (Dzień $currentDay)',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...activePlan.entriesForDay(currentDay).map((entry) {
                    return _buildMealItem(context, entry);
                  }).toList(),
                ] else ...[
                  // Brak aktywnego planu - pusta sekcja zachęcająca do stworzenia
                  _buildNoPlanCard(context).animate().fadeIn(delay: 200.ms),
                ],
              ],
            ),
          ),
        ),
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
    final consumedKcal = summary?.totalCalories ?? 0.0;
    final targetKcal = summary?.targetCalories ?? 2000.0;
    final consumedProtein = summary?.totalProtein ?? 0.0;
    final consumedFat = summary?.totalFat ?? 0.0;
    final consumedCarbs = summary?.totalCarbs ?? 0.0;

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
        ],
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
    final tip = kCookingTips[dayOfYear % kCookingTips.length];

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CookingTipsScreen()),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
