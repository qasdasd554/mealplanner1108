import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../models/store.dart';
import '../../theme/app_theme.dart';

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
    {'id': 'gluten', 'name': 'Gluten', 'emoji': '🌾'},
    {'id': 'laktoza', 'name': 'Laktoza', 'emoji': '🥛'},
    {'id': 'orzechy', 'name': 'Orzechy', 'emoji': '🥜'},
    {'id': 'jaja', 'name': 'Jaja', 'emoji': '🥚'},
    {'id': 'soja', 'name': 'Soja', 'emoji': '🫘'},
    {'id': 'seler', 'name': 'Seler', 'emoji': '🥬'},
    {'id': 'ryby', 'name': 'Ryby', 'emoji': '🐟'},
    {'id': 'skorupiaki', 'name': 'Skorupiaki', 'emoji': '🍤'},
  ];

  final List<Map<String, String>> _dietsList = [
    {'name': 'Bez ograniczeń', 'desc': 'Jesz wszystko, na co masz ochotę', 'emoji': '🍽️'},
    {'name': 'Wegetariańska', 'desc': 'Posiłki bez mięsa i ryb', 'emoji': '🥦'},
    {'name': 'Wegańska', 'desc': 'Posiłki w 100% roślinne', 'emoji': '🌱'},
    {'name': 'Bezglutenowa', 'desc': 'Dania bez zawartości glutenu', 'emoji': '🌾❌'},
    {'name': 'Keto', 'desc': 'Niska zawartość węglowodanów', 'emoji': '🥩'},
    {'name': 'Wysokobiałkowa', 'desc': 'Dla aktywnych, budujących masę', 'emoji': '💪'},
  ];

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
    if (_currentPage < 3) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Nie udało się zapisać preferencji'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Pasek postępu (Kropki)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) => _buildDot(index)),
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
                      child: const Text('Wstecz', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  else
                    const SizedBox.shrink(),

                  // Przycisk "Dalej" / "Gotowe"
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 48),
                    ),
                    child: Text(_currentPage == 3 ? 'Gotowe! 🎉' : 'Dalej'),
                  ),
                ],
              ),
            ),
          ],
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
            'Gdzie robisz zakupy? 🛒',
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
            'Czy masz jakieś alergie? 🚫',
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
                        Text(
                          allergen['emoji']!,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          allergen['name']!,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 16,
                                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
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
            'Wybierz swoją dietę 🥗',
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
                        Text(
                          diet['emoji']!,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 16),
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
            'Dla ilu osób gotujesz? 👨‍👩‍👧‍👦',
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
