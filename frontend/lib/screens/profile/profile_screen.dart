import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/shopping_list_provider.dart';
import '../../providers/promotion_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_badge.dart';
import 'premium_screen.dart';
import '../admin/admin_panel_screen.dart';

/// Odmiana słowa "dzień" — w polskim wystarczy rozróżnić TYLKO liczbę 1
/// (dzień) od wszystkich pozostałych (dni), w przeciwieństwie do wielu
/// innych rzeczowników z trójstopniową odmianą (1/2-4/5+).
String _dayWord(int days) => days == 1 ? 'dzień' : 'dni';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final user = authProvider.currentUser;

    String getStoreName(String? id) {
      if (id == null) return 'Brak';
      try {
        return storeProvider.stores.firstWhere((s) => s.id == id).name;
      } catch (_) {
        return 'Sklep';
      }
    }

    final storeName = getStoreName(user?.preferredStoreId);

    // Wyciągnij dietę z JSONa preferencji
    final diet = user?.dietaryPreferences?['diet'] as String? ?? 'Bez ograniczeń';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Sekcja awatara i danych użytkownika
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Text(
                      user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'Użytkownik',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (user?.hasPremiumAccess ?? false) ...[
                    const SizedBox(height: 8),
                    const PremiumBadge(),
                  ],
                  // Dni pozostałe do wygaśnięcia subskrypcji — widoczne
                  // tylko dla kont Premium z ustawioną datą wygaśnięcia
                  // (konta administratora mają dostęp premium bez
                  // subskrypcji, więc premiumDaysRemaining jest tam null).
                  if (user?.premiumDaysRemaining != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      user!.premiumDaysRemaining == 0
                          ? 'Subskrypcja wygasa dziś'
                          : 'Subskrypcja aktywna jeszcze przez ${user.premiumDaysRemaining} '
                              '${_dayWord(user.premiumDaysRemaining!)}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Baner "Zostań Premium" — widoczny TYLKO dla kont bez
            // dostępu premium (admini i już-premium go nie widzą, bo im
            // niepotrzebny).
            if (!(user?.hasPremiumAccess ?? false))
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6D28D9), Color(0xFFE0A62E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Zostań Premium',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Plany bez limitu, przepisy AI i więcej',
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ).animate().fadeIn().shimmer(delay: 600.ms, duration: 1200.ms),

            const SizedBox(height: 24),

            // Wejście do panelu administratora — widoczne TYLKO dla
            // kont z rolą "admin".
            if (user?.isAdmin ?? false)
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: AppTheme.surfaceColor,
                    border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.secondaryColor),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Panel administratora',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: AppTheme.textSecondary, size: 16),
                    ],
                  ),
                ),
              ),

            if (user?.isAdmin ?? false) const SizedBox(height: 24),

            // 2. Sekcja preferencji i ustawień
            Text(
              'Twoje ustawienia',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Karta Sklepu
            _buildProfileSettingTile(
              context,
              icon: Icons.storefront_outlined,
              title: 'Preferowany sklep',
              value: storeName,
              onTap: () {
                _showStorePicker(context, authProvider, storeProvider);
              },
            ),
            const SizedBox(height: 12),

            // Karta Diety
            _buildProfileSettingTile(
              context,
              icon: Icons.restaurant_outlined,
              title: 'Rodzaj diety',
              value: diet,
              onTap: () {
                _showDietPicker(context, authProvider, diet);
              },
            ),
            const SizedBox(height: 12),

            // Karta wielkości gospodarstwa
            _buildProfileSettingTile(
              context,
              icon: Icons.people_outline,
              title: 'Liczba osób w gospodarstwie',
              value: '${user?.householdSize ?? 1} os.',
              onTap: () {
                _showHouseholdSizePicker(context, authProvider, user?.householdSize ?? 1);
              },
            ),
            const SizedBox(height: 32),

            // Przełącznik trybu ciemnego
            Material(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: InkWell(
                onTap: () => themeProvider.toggle(),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        themeProvider.isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Tryb ciemny',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
                        ),
                      ),
                      Switch(
                        value: themeProvider.isDark,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (value) => themeProvider.setDark(value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 3. Wylogowanie
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor, width: 1.5),
              ),
              onPressed: () async {
                // UWAGA (naprawa poważnego błędu): wcześniej wylogowanie
                // czyściło TYLKO stan AuthProvider — żaden z pozostałych
                // providerów (plany posiłków, dziennik kalorii, lista
                // zakupów, promocje, sklepy) nie był resetowany. Niektóre
                // ekrany (np. zakładka "Plan" w Śledzeniu kalorii) ładują
                // dane TYLKO gdy lokalna lista jest pusta — efekt: po
                // zalogowaniu się jako inny użytkownik, wciąż widoczne
                // były dane POPRZEDNIEGO użytkownika, dopóki coś jawnie
                // nie wymusiło ponownego pobrania. To realny wyciek
                // danych między kontami na tym samym urządzeniu.
                Provider.of<MealPlanProvider>(context, listen: false).clear();
                Provider.of<FoodLogProvider>(context, listen: false).clear();
                Provider.of<ShoppingListProvider>(context, listen: false).clear();
                Provider.of<PromotionProvider>(context, listen: false).clear();
                Provider.of<StoreProvider>(context, listen: false).clear();
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              child: const Text('Wyloguj się'),
            ),
            const SizedBox(height: 48),

            // Wersja aplikacji
            Center(
              child: Text(
                'v1.0.0 (Meal Planner)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStorePicker(BuildContext context, AuthProvider auth, StoreProvider storeProv) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Wybierz sklep', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...storeProv.stores.map((store) => ListTile(
                      title: Text(store.name),
                      trailing: auth.currentUser?.preferredStoreId == store.id
                          ? const Icon(Icons.check, color: AppTheme.primaryColor)
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await auth.updateProfile(preferredStoreId: store.id);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDietPicker(BuildContext context, AuthProvider auth, String currentDiet) {
    final diets = ['Bez ograniczeń', 'Wegetariańska', 'Wegańska', 'Keto', 'Bez laktozy'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rodzaj diety', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...diets.map((diet) => ListTile(
                      title: Text(diet),
                      trailing: currentDiet == diet
                          ? const Icon(Icons.check, color: AppTheme.primaryColor)
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final currentPrefs = auth.currentUser?.dietaryPreferences ?? {};
                        final newPrefs = Map<String, dynamic>.from(currentPrefs);
                        newPrefs['diet'] = diet;
                        await auth.updateProfile(dietaryPreferences: newPrefs);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHouseholdSizePicker(BuildContext context, AuthProvider auth, int currentSize) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Liczba osób w gospodarstwie', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...List.generate(6, (index) {
                  final size = index + 1;
                  return ListTile(
                    title: Text('$size os.'),
                    trailing: currentSize == size
                        ? const Icon(Icons.check, color: AppTheme.primaryColor)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await auth.updateProfile(householdSize: size);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    // UWAGA: wcześniej ten Container przyjmował parametr `onTap`, ale nigdy
    // go nie używał — kafelek wyglądał jak przycisk, ale dotknięcie nic nie
    // robiło. Stąd "żaden przycisk oprócz Wyloguj się nie działał".
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
