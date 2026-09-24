import 'package:image_picker/image_picker.dart';
import '../../utils/error_utils.dart';
import 'dart:io';
import 'dart:convert';
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
import '../../providers/wellness_provider.dart';
import '../../models/weight_log.dart';
import '../../services/weight_log_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_badge.dart';
import '../tracker/calorie_calculator_screen.dart';
import '../../widgets/premium_comparison_table.dart';
import '../../widgets/decorative_circles.dart';
import '../../widgets/user_avatar.dart';
import 'premium_screen.dart';
import '../admin/admin_panel_screen.dart';
import 'blocked_users_screen.dart';
import 'statistics_screen.dart';
import 'friends_screen.dart';

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
      body: Stack(
        children: [
          const DecorativeCircles(),
          SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Sekcja awatara i danych użytkownika
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _showAvatarPicker(context, authProvider),
                    child: Stack(
                      children: [
                        UserAvatar(avatar: user?.avatar, avatarPhotoBase64: user?.avatarPhotoBase64, size: 100),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showEditNicknameDialog(context, authProvider),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.displayName ?? 'Użytkownik',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit, size: 18, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                  if (user?.hasPremiumAccess ?? false) ...[
                    const SizedBox(height: 8),
                    const PremiumBadge(),
                  ],
                  // Dni pozostałe do wygaśnięcia subskrypcji.
                  //
                  // NAPRAWA: warunek sprawdzał tylko `!= null`, a getter
                  // premiumDaysRemaining zwraca 0 (nie null), gdy data
                  // wygaśnięcia już minęła. Po wygaśnięciu subskrypcji
                  // napis "Subskrypcja wygasa dziś" wisiał więc
                  // w nieskończoność, mimo że konto dawno straciło
                  // Premium. Dokładamy warunek hasPremiumAccess, który
                  // uwzględnia datę (patrz models/user.dart).
                  if ((user?.hasPremiumAccess ?? false) &&
                      user?.premiumDaysRemaining != null) ...[
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

            _ProfileSection(
              title: 'Zdrowie i cele',
              icon: Icons.monitor_heart_outlined,
              children: [
                _buildCalorieCalculatorTile(context),
                const SizedBox(height: 16),
                const _WeightTrackerCard(),
              ],
            ),
            const SizedBox(height: 12),

            _ProfileSection(
              title: 'Społeczność',
              icon: Icons.people_alt_outlined,
              children: [
                _buildProfileSettingTile(
                  context,
                  icon: Icons.group_outlined,
                  title: 'Znajomi',
                  value: 'Zaproszenia, przepisy i listy zakupów',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FriendsScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            _ProfileSection(
              title: 'Subskrypcja',
              icon: Icons.workspace_premium_outlined,
              children: [
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

            // Tabela porównawcza Premium vs Standard — widoczna dla
            // wszystkich: dla kont bez Premium to zachęta do zakupu, dla
            // kont Premium potwierdzenie, co dokładnie zyskują.
            Text(
              'Porównanie planów',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const PremiumComparisonTable(),
              ],
            ),
            const SizedBox(height: 12),

            _ProfileSection(
              title: 'Preferencje',
              icon: Icons.tune,
              children: [
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
              ],
            ),
            const SizedBox(height: 12),

            _ProfileSection(
              title: 'Konto i prywatność',
              icon: Icons.manage_accounts_outlined,
              children: [
            if (user?.isAdmin ?? false) ...[
              _buildAdminTile(context),
              const SizedBox(height: 16),
            ],
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
                Provider.of<WellnessProvider>(context, listen: false).clear();
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
            const SizedBox(height: 12),

            // Zablokowani użytkownicy
            OutlinedButton.icon(
              icon: const Icon(Icons.block, size: 18),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                );
              },
              label: const Text('Zablokowani użytkownicy'),
            ),
            const SizedBox(height: 24),

            // Usunięcie konta — celowo oddzielone od reszty (kolor,
            // opis ostrzegawczy) i wymaga DWÓCH potwierdzeń, bo operacja
            // jest natychmiastowa i nieodwracalna (Apple Guideline
            // 5.1.1(v) / wymóg Google Play — usuwanie konta musi być
            // możliwe WEWNĄTRZ aplikacji, nie tylko przez support).
            TextButton(
              onPressed: () => _showDeleteAccountDialog(context, authProvider),
              child: Text(
                'Usuń konto',
                style: TextStyle(color: AppTheme.errorColor.withOpacity(0.7)),
              ),
            ),
              ],
            ),
            const SizedBox(height: 24),

            // Wersja aplikacji
            Center(
              child: Text(
                'v1.0.22 (Meal Planner)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildAdminTile(BuildContext context) {
    return InkWell(
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
          border: Border.all(
            color: AppTheme.textSecondary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Panel administratora',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.textSecondary,
              size: 16,
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


  /// Kafelek prowadzący do kalkulatora zapotrzebowania kalorycznego.
  /// Pokazuje od razu wagę i BMI, żeby najczęściej sprawdzane wartości
  /// były widoczne bez wchodzenia w ekran.
  Widget _buildCalorieCalculatorTile(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final weight = user?.weightKg;
    final height = user?.heightCm;

    double? bmi;
    if (weight != null && height != null && height > 0) {
      final m = height / 100;
      bmi = weight / (m * m);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CalorieCalculatorScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppTheme.surfaceColor,
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.monitor_weight_outlined,
                  color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Waga, wzrost i cel kaloryczny',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    bmi == null
                        ? 'Uzupełnij dane, aby obliczyć BMI i zapotrzebowanie'
                        : '${weight!.toStringAsFixed(1)} kg · BMI '
                            '${bmi.toStringAsFixed(1)} — ${_bmiLabel(bmi)}',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Nazwa przedziału BMI wg WHO — bez oceniania, bo BMI nie uwzględnia
  /// budowy ciała ani masy mięśniowej.
  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'niedowaga';
    if (bmi < 25) return 'waga prawidłowa';
    if (bmi < 30) return 'nadwaga';
    return 'otyłość';
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

class _ProfileSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: AppTheme.primaryColor),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          children: children,
        ),
      ),
    );
  }
}

class _WeightTrackerCard extends StatefulWidget {
  const _WeightTrackerCard();

  @override
  State<_WeightTrackerCard> createState() => _WeightTrackerCardState();
}

class _WeightTrackerCardState extends State<_WeightTrackerCard> {
  final WeightLogService _service = WeightLogService();
  final TextEditingController _controller = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<WeightLogEntry> _logs = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final currentWeight =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.weightKg;
    if (currentWeight != null) {
      _controller.text = currentWeight.toStringAsFixed(1);
    }
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final logs = await _service.getLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(error);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      helpText: 'Data pomiaru',
      cancelText: 'Anuluj',
      confirmText: 'Wybierz',
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedDate = selected;
        final existing = _logs.where((entry) => _sameDay(entry.date, selected));
        if (existing.isNotEmpty) {
          _controller.text = existing.first.weightKg.toStringAsFixed(1);
        }
      });
    }
  }

  Future<void> _save() async {
    final weight = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (weight == null || weight <= 0 || weight > 400) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Podaj prawidłową wagę od 0,1 do 400 kg.'),
        ));
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.save(_selectedDate, weight);
      if (!mounted) return;
      await Provider.of<AuthProvider>(context, listen: false).loadProfile();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Zapisano ${weight.toStringAsFixed(1)} kg.'),
        ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Śledzenie wagi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Zapisz pomiar dla wybranego dnia. Ponowny zapis poprawi wpis z tej samej daty.',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 17),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Data: ${_dateLabel(_selectedDate)}'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Waga (opcjonalnie)',
              suffixText: 'kg',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_chart, size: 18),
            label: const Text('Zapisz pomiar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            ),
            icon: const Icon(Icons.insights_outlined, size: 18),
            label: const Text('Statystyki'),
          ),
          if (_loading) ...[
            const SizedBox(height: 14),
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ] else if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(fontSize: 11, color: AppTheme.errorColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pokazuje dolny panel z wyborem awatara — dwie gotowe opcje (kobieta/
/// mężczyzna) plus możliwość usunięcia wyboru (powrót do neutralnej
/// ikony). Zapisuje wybór od razu po dotknięciu, bez osobnego przycisku
/// "Zapisz" — mniej tarcia dla tak prostej decyzji.
/// Zdejmuje zdjęcie z aparatu albo galerii i zapisuje jako awatar.
///
/// Ograniczenia dobrane MNIEJSZE niż przy zdjęciach przepisów (1600 px,
/// jakość 85, limit 3 MB) — awatar renderuje się jako małe kółko w
/// dziesiątkach miejsc naraz (komentarze, ranking), więc nie ma sensu
/// trzymać w bazie dużego pliku tylko po to, żeby go potem zmniejszać
/// przy każdym wyświetleniu.
Future<void> _pickAvatarPhoto(
  BuildContext context,
  AuthProvider authProvider,
  ImageSource source,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await File(picked.path).readAsBytes();
    final base64Photo = base64Encode(bytes);

    final ok = await authProvider.updateProfile(avatarPhotoBase64: base64Photo);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(authProvider.errorMessage ?? 'Nie udało się zapisać zdjęcia'),
        ));
    }
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(friendlyError(e)),
      ));
  }
}

void _showAvatarPicker(BuildContext context, AuthProvider authProvider) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final current = authProvider.currentUser?.avatar;
      final hasPhoto = (authProvider.currentUser?.avatarPhotoBase64 ?? '').isNotEmpty;

      Widget option(String value, String label) {
        return GestureDetector(
          onTap: () async {
            Navigator.of(sheetContext).pop();
            // Wybór GOTOWEJ ikony kasuje własne zdjęcie (pusty string,
            // nie null — patrz walidacja w backendzie), żeby ikona
            // faktycznie zastąpiła zdjęcie zamiast zostać przez nie
            // przysłonięta (UserAvatar daje zdjęciu pierwszeństwo).
            await authProvider.updateProfile(avatar: value, avatarPhotoBase64: '');
          },
          child: Column(
            children: [
              UserAvatar(avatar: value, size: 72, selected: current == value && !hasPhoto),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }

      Widget photoOption(IconData icon, String label, ImageSource source) {
        return GestureDetector(
          onTap: () {
            Navigator.of(sheetContext).pop();
            _pickAvatarPhoto(context, authProvider, source);
          },
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 30),
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }

      return SafeArea(
        // UWAGA (naprawa — ten sam błąd, co wcześniej z przyciskami
        // wjeżdżającymi pod pasek nawigacji): panel wyboru awatara nie
        // był chroniony SafeArea, więc w trybie edge-to-edge mógł
        // częściowo chować się pod systemowym paskiem na dole ekranu.
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Wybierz awatar', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 24),
              // Własne zdjęcie — NOWOŚĆ. Aparat i galeria w jednym rzędzie,
              // nad gotowymi ikonami, bo to opcja, którą chcemy wyeksponować.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  photoOption(Icons.camera_alt, 'Zrób zdjęcie', ImageSource.camera),
                  photoOption(Icons.photo_library, 'Z galerii', ImageSource.gallery),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'albo wybierz ikonę',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  option('female', 'Kobieta'),
                  option('male', 'Mężczyzna'),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
}

/// Edycja pseudonimu (display_name) — pole już istniało w profilu i w
/// PUT /users/me, brakowało tylko interfejsu do jego zmiany po
/// rejestracji (wcześniej ustawiało się tylko raz, przy zakładaniu konta).
void _showEditNicknameDialog(BuildContext context, AuthProvider authProvider) {
  final controller = TextEditingController(text: authProvider.currentUser?.displayName ?? '');
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Zmień pseudonim'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Pseudonim',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.of(dialogContext).pop();
              final success = await authProvider.updateProfile(displayName: newName);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
                  SnackBar(
            duration: const Duration(seconds: 3),
                    content: Text(
                      success ? 'Pseudonim zaktualizowany.' : 'Nie udało się zmienić pseudonimu.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Zapisz'),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}

/// Usunięcie konta — dwuetapowe potwierdzenie, bo operacja jest
/// natychmiastowa i całkowicie nieodwracalna (backend kaskadowo usuwa
/// WSZYSTKIE dane: plany, listy zakupów, przepisy, komentarze...).
void _showDeleteAccountDialog(BuildContext context, AuthProvider authProvider) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Usunąć konto na stałe?'),
        content: const Text(
          'Ta operacja jest NIEODWRACALNA. Stracisz wszystkie zapisane plany '
          'posiłków, listy zakupów, spiżarnię, ulubione przepisy, komentarze '
          'i punkty premium. Jeśli masz aktywną subskrypcję, pamiętaj, żeby '
          'anulować ją osobno w ustawieniach App Store / Google Play — '
          'usunięcie konta samo jej nie anuluje.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Anuluj'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showFinalDeleteConfirmation(context, authProvider);
            },
            child: const Text('Dalej'),
          ),
        ],
      );
    },
  );
}

void _showFinalDeleteConfirmation(BuildContext context, AuthProvider authProvider) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Ostatnie potwierdzenie'),
        content: const Text('Na pewno? Tej operacji nie da się cofnąć.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final success = await authProvider.deleteAccount();
              if (context.mounted) {
                if (success) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                } else {
                  ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
                    const SnackBar(
            duration: Duration(seconds: 3),content: Text('Nie udało się usunąć konta. Spróbuj ponownie.')),
                  );
                }
              }
            },
            child: const Text('Usuń konto'),
          ),
        ],
      );
    },
  );
}
