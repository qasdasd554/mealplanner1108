import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../models/store.dart';
import '../../models/meal_plan.dart';
import '../../theme/app_theme.dart';
import '../profile/premium_screen.dart';

class PlanConfigScreen extends StatefulWidget {
  const PlanConfigScreen({super.key});

  @override
  State<PlanConfigScreen> createState() => _PlanConfigScreenState();
}

class _PlanConfigScreenState extends State<PlanConfigScreen> {
  Store? _selectedStore;
  int _durationDays = 5;
  int _householdSize = 1;
  final _budgetController = TextEditingController();
  final _kcalController = TextEditingController(text: '2000');
  final Set<String> _selectedMealTypes = {'śniadanie', 'obiad', 'kolacja'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Ustaw sklep z preferencji użytkownika
      if (authProvider.currentUser?.preferredStoreId != null) {
        storeProvider.selectStoreById(authProvider.currentUser!.preferredStoreId!);
        setState(() {
          _selectedStore = storeProvider.selectedStore;
        });
      }
      // Domyślna liczba osób — z profilu użytkownika, ale można ją zmienić
      // tylko dla tego konkretnego planu (np. akurat gotujesz dla gości).
      final profileHouseholdSize = authProvider.currentUser?.householdSize;
      if (profileHouseholdSize != null && profileHouseholdSize > 0) {
        setState(() {
          _householdSize = profileHouseholdSize;
        });
      }
    });
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _kcalController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wybierz sklep przed wygenerowaniem planu!'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    double? maxBudget;
    if (_budgetController.text.isNotEmpty) {
      maxBudget = double.tryParse(_budgetController.text);
    }

    int? targetKcal;
    if (_kcalController.text.isNotEmpty) {
      targetKcal = int.tryParse(_kcalController.text);
    }

    // UWAGA (naprawa poważnego błędu): wcześniej preferencja diety
    // zapisana podczas onboardingu (np. "Keto", "Wegańska") NIGDY nie
    // była faktycznie wysyłana przy generowaniu planu — tylko meal_types.
    // Efekt: filtr diety w backendzie nigdy się nie uruchamiał, więc
    // KAŻDY plan ignorował ograniczenia dietetyczne całkowicie —
    // użytkownik na diecie ketogenicznej mógł dostać w planie pizzę.
    final userDiet = Provider.of<AuthProvider>(context, listen: false)
        .currentUser
        ?.dietaryPreferences?['diet'] as String?;

    final request = MealPlanGenerateRequest(
      storeId: _selectedStore!.id,
      durationDays: _durationDays,
      mealsPerDay: _selectedMealTypes.length,
      maxBudget: maxBudget,
      targetKcal: targetKcal,
      householdSize: _householdSize,
      preferences: {
        'meal_types': _selectedMealTypes.toList(),
        if (userDiet != null && userDiet != 'Bez ograniczeń') 'diet': userDiet,
      },
    );

    final mealPlanProvider = Provider.of<MealPlanProvider>(context, listen: false);
    final success = await mealPlanProvider.generatePlan(request);

    if (mounted) {
      if (success) {
        await _showBudgetConfirmation(mealPlanProvider.currentPlan);
      } else {
        final errorMsg = mealPlanProvider.errorMessage ?? 'Nie udało się wygenerować planu';
        // Błąd limitu darmowego konta wspomina Premium w treści (patrz
        // backend) — dokładamy wtedy przycisk prowadzący wprost do
        // ekranu zakupu, zamiast zostawiać to tylko jako tekst.
        final isLimitError = errorMsg.contains('Premium');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 6),
            action: isLimitError
                ? SnackBarAction(
                    label: 'PREMIUM',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PremiumScreen()),
                      );
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  /// Pokazuje szacowany minimalny koszt zakupów od razu w momencie
  /// utworzenia planu — zanim użytkownik przejdzie do jego pełnego
  /// widoku — zamiast chować tę informację na osobnym ekranie.
  Future<void> _showBudgetConfirmation(MealPlan? plan) async {
    final budget = plan?.estimatedMinBudget;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Plan gotowy! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Twój plan na $_durationDays dni dla '
              '${_householdSize == 1 ? "1 osoby" : "$_householdSize osób"} jest gotowy.',
            ),
            const SizedBox(height: 16),
            if (budget != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Szacowany minimalny koszt zakupów',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${budget.toStringAsFixed(2)} zł',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            // Dla kont standardowych (bez Premium) — proaktywna informacja
            // o limicie, ZANIM na niego trafią (nie tylko reaktywnie, gdy
            // spróbują wygenerować drugi plan i zostaną zablokowani).
            if (!(Provider.of<AuthProvider>(context, listen: false).currentUser?.hasPremiumAccess ?? false)) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.secondaryColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Na koncie standardowym masz jeden plan naraz',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Premium pozwala mieć kilka planów jednocześnie (np. osobny na dni robocze i weekend).',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!(Provider.of<AuthProvider>(context, listen: false).currentUser?.hasPremiumAccess ?? false))
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
              },
              child: const Text('Poznaj Premium'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacementNamed('/plan/view');
            },
            child: const Text('Zobacz plan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final mealPlanProvider = Provider.of<MealPlanProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nowy plan posiłków'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Sklep
                Text(
                  'Wybierz sklep',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: storeProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
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
                                width: 130,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      store.name,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                                          ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(height: 4),
                                      const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 16),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ).animate().fadeIn(),
                const SizedBox(height: 32),

                // 2. Czas trwania planu
                Text(
                  'Czas trwania planu: $_durationDays dni',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      Slider(
                        value: _durationDays.toDouble(),
                        min: 3,
                        max: 14,
                        divisions: 11,
                        activeColor: AppTheme.primaryColor,
                        inactiveColor: AppTheme.backgroundColor,
                        label: '$_durationDays dni',
                        onChanged: (value) {
                          setState(() {
                            _durationDays = value.toInt();
                          });
                        },
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('3 dni', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            Text('7 dni', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            Text('14 dni', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 32),

                // 2b. Liczba osób
                Text(
                  'Dla ilu osób gotujesz: $_householdSize'
                  '${_householdSize == 1 ? " osoba" : (_householdSize < 5 ? " osoby" : " osób")}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Domyślnie z Twojego profilu — możesz to zmienić tylko dla tego planu.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppTheme.primaryColor,
                        onPressed: _householdSize > 1
                            ? () => setState(() => _householdSize--)
                            : null,
                      ),
                      Expanded(
                        child: Slider(
                          value: _householdSize.toDouble(),
                          min: 1,
                          max: 8,
                          divisions: 7,
                          activeColor: AppTheme.primaryColor,
                          inactiveColor: AppTheme.backgroundColor,
                          label: '$_householdSize',
                          onChanged: (value) {
                            setState(() {
                              _householdSize = value.toInt();
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppTheme.primaryColor,
                        onPressed: _householdSize < 8
                            ? () => setState(() => _householdSize++)
                            : null,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 32),

                // 3. Typy posiłków
                Text(
                  'Typy posiłków',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['śniadanie', 'obiad', 'kolacja', 'przekąska'].map((type) {
                      final isSelected = _selectedMealTypes.contains(type);
                      final emoji = {
                        'śniadanie': '',
                        'obiad': '',
                        'kolacja': '',
                        'przekąska': '',
                      }[type] ?? '';
                      return FilterChip(
                        label: Text('$emoji $type'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedMealTypes.add(type);
                            } else {
                              if (_selectedMealTypes.length > 1) {
                                _selectedMealTypes.remove(type);
                              }
                            }
                          });
                        },
                        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                        checkmarkColor: AppTheme.primaryColor,
                        backgroundColor: AppTheme.backgroundColor,
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                          width: 1,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      );
                    }).toList(),
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 32),

                // 4. Cel kaloryczny
                Text(
                  'Cel kaloryczny dziennie',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _kcalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Docelowe kcal / dzień / osoba',
                    hintText: 'np. 2000',
                    suffixText: 'kcal',
                  ),
                ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 32),

                // 5. Budżet (opcjonalnie)
                Text(
                  'Maksymalny budżet (opcjonalnie)',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Maksymalny budżet',
                    hintText: 'np. 150.00',
                    suffixText: 'PLN',
                  ),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 48),

                // Przycisk generowania
                ElevatedButton(
                  onPressed: mealPlanProvider.isGenerating ? null : _generate,
                  child: Text(mealPlanProvider.isGenerating ? 'Generowanie...' : 'Wygeneruj plan!'),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
          
          // Nakładka ładowania w trakcie generowania
          if (mealPlanProvider.isGenerating)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Układamy Twój optymalny plan posiłków...',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Maksymalizujemy ponowne wykorzystanie składników, aby zmniejszyć cenę zakupów.',
                      style: TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
