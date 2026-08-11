import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);

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
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

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

            // 3. Wylogowanie
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor, width: 1.5),
              ),
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              child: const Text('Wyloguj się'),
            ),
            const SizedBox(height: 48),

            // Wersja aplikacji
            const Center(
              child: Text(
                'v1.0.0 (Smart Meal Planner PL)',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
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
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}
