import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../models/store.dart';
import '../../config/constants.dart';
import '../../theme/app_theme.dart';
import 'welcome_bonus_screen.dart';
import '../recipes/pantry_screen.dart';
import '../tracker/calorie_calculator_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Preferencje wybrane podczas onboarding
  Store? _selectedStore;
  final List<String> _selectedAllergens = [];
  String _selectedDiet = 'Bez ograniczeń';
  int _householdSize = 1;

  final List<Map<String, String>> _allergensList = [
    {'id': 'gluten', 'name': 'Gluten'},
    {'id': 'laktoza', 'name': 'Laktoza'},
    {'id': 'orzechy', 'name': 'Orzechy'},
    {'id': 'jaja', 'name': 'Jaja'},
    {'id': 'soja', 'name': 'Soja'},
    {'id': 'seler', 'name': 'Seler'},
    {'id': 'ryby', 'name': 'Ryby'},
    {'id': 'skorupiaki', 'name': 'Skorupiaki'},
  ];

  final List<Map<String, String>> _dietsList = kDietOptions;

  @override
  void initState() {
    super.initState();
    // Załaduj sklepy z serwera na początku onboarding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StoreProvider>(context, listen: false).loadStores();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
            duration: Duration(seconds: 3),
          content: Text('Wybierz swój preferowany sklep!'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.saveOnboardingPreferences(
      storeId: _selectedStore!.id,
      allergenIds: _selectedAllergens,
      diet: _selectedDiet,
      householdSize: _householdSize,
    );

    if (mounted) {
      if (success) {
        // Ekran z punktami powitalnymi pokazujemy TYLKO gdy faktycznie
        // zostały przyznane — przy powtórnym przejściu onboardingu
        // (bonus już odebrany) gratulacje byłyby mylące.
        final bonus = authProvider.lastBonusPoints;
        if (bonus > 0) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => WelcomeBonusScreen(points: bonus)),
          );
        } else {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(authProvider.errorMessage ?? 'Nie udało się zapisać preferencji'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _previousPage();
      },
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Pasek postępu (Kropki)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (index) => _buildDot(index)),
              ),
            ),

            // Zawartość stron
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildStoreStep(),
                  _buildAllergensStep(),
                  _buildDietStep(),
                  _buildHouseholdStep(),
                  _buildProfileStep(),
                  _buildPantryStep(),
                  _buildAiRecipeStep(),
                ],
              ),
            ),

            // Przyciski nawigacyjne na dole
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Przycisk "Wstecz"
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: Text('Wstecz', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  else
                    const SizedBox.shrink(),

                  // Przycisk "Dalej" / "Gotowe"
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 48),
                    ),
                    child: Text(_currentPage == 6 ? 'Gotowe!' : 'Dalej'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : AppTheme.surfaceColor,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
    );
  }

  // --- KROK 1: Wybór sklepu ---
  Widget _buildStoreStep() {
    final storeProvider = Provider.of<StoreProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Gdzie robisz zakupy?',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Wybierz sklep, w którym najczęściej robisz zakupy. Dostosujemy plan posiłków i produkty pod ten konkretny asortyment.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (storeProvider.isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (storeProvider.errorMessage != null)
            Expanded(
              child: Center(
                child: Text(
                  'Błąd wczytywania sklepów:\n${storeProvider.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: storeProvider.stores.length,
                itemBuilder: (context, index) {
                  final store = storeProvider.stores[index];
                  final isSelected = _selectedStore?.id == store.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStore = store;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: const BorderRadius.all(Radius.circular(16)),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Custom Logo / Icon w zależności od sklepu
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withOpacity(0.1)
                                  : AppTheme.backgroundColor,
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                            ),
                            child: Center(
                              child: Text(
                                store.name[0],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            store.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppTheme.primaryColor),
                        ],
                      ),
                    ).animate().fadeIn(delay: (index * 100).ms),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- KROK 2: Alergie ---
  Widget _buildAllergensStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Czy masz jakieś alergie?',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Wybierz składniki, których nie możesz jeść. Przepisy zawierające te alergeny nie będą sugerowane.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
              ),
              itemCount: _allergensList.length,
              itemBuilder: (context, index) {
                final allergen = _allergensList[index];
                final isSelected = _selectedAllergens.contains(allergen['id']);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedAllergens.remove(allergen['id']!);
                      } else {
                        _selectedAllergens.add(allergen['id']!);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : AppTheme.surfaceColor,
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            allergen['name']!,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 16,
                                  color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- KROK 3: Dieta ---
  Widget _buildDietStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Wybierz swoją dietę',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Dostosujemy rekomendacje przepisów do Twojego stylu żywieniowego.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _dietsList.length,
              itemBuilder: (context, index) {
                final diet = _dietsList[index];
                final isSelected = _selectedDiet == diet['name'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDiet = diet['name']!;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                diet['name']!,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                diet['desc']!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- KROK 4: Liczba osób ---
  Widget _buildHouseholdStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dla ilu osób gotujesz?',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Automatycznie dopasujemy ilości składników w przepisach oraz porcje w liście zakupowej.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Licznik
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Przycisk minus
              _buildCounterButton(
                icon: Icons.remove,
                onPressed: () {
                  if (_householdSize > 1) {
                    setState(() {
                      _householdSize--;
                    });
                  }
                },
              ),
              const SizedBox(width: 32),
              // Liczba
              Text(
                '$_householdSize',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 32),
              // Przycisk plus
              _buildCounterButton(
                icon: Icons.add,
                onPressed: () {
                  if (_householdSize < 10) {
                    setState(() {
                      _householdSize++;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _householdSize == 1
                ? 'Gotuję tylko dla siebie'
                : 'Liczba osób w gospodarstwie: $_householdSize',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- KROK 5: Dane zdrowotne ---
  Widget _buildProfileStep() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        const Icon(Icons.monitor_weight_outlined, size: 56, color: AppTheme.primaryColor),
        const SizedBox(height: 16),
        Text('Twój profil i cel', style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Chcesz teraz obliczyć zapotrzebowanie kaloryczne i uzupełnić wagę, wzrost oraz cel? Możesz też zrobić to później w profilu.',
            style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () async {
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const CalorieCalculatorScreen()),
            );
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.calculate_outlined),
          label: const Text(
            'Otwórz kalkulator zapotrzebowania',
            maxLines: 2,
            softWrap: true,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 18),
        Text('Ten krok jest opcjonalny. Wybierz „Dalej”, aby go pominąć.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }

  // --- KROK 6: Spiżarnia ---
  Widget _buildPantryStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 42,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Co masz w spiżarni?',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Dodaj produkty, które masz już w domu. Dzięki temu łatwiej znajdziesz przepisy bez dodatkowych zakupów.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantryScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text(
              'Dodaj produkty do spiżarni',
              maxLines: 2,
              softWrap: true,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ten krok możesz pominąć.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // KROK 7: odkrycie importu AI bez dokładania przycisków na ekranie głównym.
  Widget _buildAiRecipeStep() {
    Widget option(IconData icon, String title, String description) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 25),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(description, style: TextStyle(color: AppTheme.textSecondary)),
            ],
          )),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      children: [
        const Icon(Icons.auto_awesome_outlined,
            size: 58, color: AppTheme.primaryColor),
        const SizedBox(height: 18),
        Text('Masz przepis? Dodaj go w chwilę',
            style: Theme.of(context).textTheme.displaySmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'W zakładce Przepisy wybierz „Dodaj przepis”. AI przygotuje składniki i kroki na podstawie:',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            option(Icons.photo_camera_outlined, 'Zdjęcia',
                'Sfotografuj kartkę z przepisem albo gotowe danie.'),
            option(Icons.text_snippet_outlined, 'Tekstu',
                'Wklej opis lub wpisz samą nazwę potrawy.'),
            option(Icons.link, 'Linku',
                'Wklej adres strony lub udostępnij go z innej aplikacji.'),
          ]),
        ),
        const SizedBox(height: 16),
        Text(
          'Przykład: w TikToku wybierz „Udostępnij” → Meal Planner Polska. '
          'Gdy przepis będzie gotowy, możesz poprosić AI o zmianę, np. wersję bez laktozy.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Text(
          'Dodanie przepisu kosztuje 2 punkty bez subskrypcji Premium. '
          'Późniejsza zmiana przez AI kosztuje 1 punkt.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCounterButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2)),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.primaryColor, size: 28),
        onPressed: onPressed,
      ),
    );
  }
}
