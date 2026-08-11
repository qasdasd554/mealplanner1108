import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/shopping_list_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/meal_plan.dart';
import '../../models/recipe.dart';
import '../recipes/recipes_screen.dart';
import '../shopping/shopping_list_screen.dart';
import '../profile/profile_screen.dart';
import '../tracker/calorie_tracker_screen.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    // Podział na taby
    final List<Widget> tabs = [
      const HomeTab(),
      const RecipesScreen(),
      const ShoppingListScreen(isTab: true),
      const ProfileScreen(),
      const CalorieTrackerScreen(),
    ];

    return Scaffold(
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Start',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_outlined),
            activeIcon: Icon(Icons.restaurant),
            label: 'Przepisy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Zakupy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_fire_department_outlined),
            activeIcon: Icon(Icons.local_fire_department),
            label: 'Tracker',
          ),
        ],
      ),
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

    final user = authProvider.currentUser;
    final activePlan = mealPlanProvider.activePlan;
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cześć, ${user?.displayName ?? 'użytkowniku'}! 👋',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Co dziś gotujemy?',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    // Szybki skrót do profilu
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/profile'),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text(
                          user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideY(begin: -0.1, end: 0),
                const SizedBox(height: 32),

                // Skróty Szybkich Akcji (H-scroll)
                Text(
                  'Szybkie akcje',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildQuickActionCard(
                        context,
                        title: 'Nowy plan',
                        subtitle: 'Zaplanuj posiłki',
                        icon: Icons.calendar_today_outlined,
                        color: AppTheme.primaryColor,
                        onTap: () => Navigator.of(context).pushNamed('/plan/config'),
                      ),
                      const SizedBox(width: 16),
                      _buildQuickActionCard(
                        context,
                        title: 'Przepisy',
                        subtitle: 'Szukaj inspiracji',
                        icon: Icons.menu_book_outlined,
                        color: AppTheme.secondaryColor,
                        onTap: () => Navigator.of(context).pushNamed('/recipes'),
                      ),
                      const SizedBox(width: 16),
                      _buildQuickActionCard(
                        context,
                        title: 'Baza produktów',
                        subtitle: 'Sprawdź ceny',
                        icon: Icons.storefront_outlined,
                        color: AppTheme.accentColor,
                        onTap: () => Navigator.of(context).pushNamed('/products'),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),
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

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 16,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                      ),
                ),
              ],
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
      decoration: const BoxDecoration(
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
                  child: const Text('Zakupy 🛒'),
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
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Row(
          children: [
            Text(
              entry.recipe.mealTypeEmoji,
              style: const TextStyle(fontSize: 28),
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
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPlanCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
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
            child: const Text('Stwórz nowy plan posiłków 🍳'),
          ),
        ],
      ),
    );
  }
}
