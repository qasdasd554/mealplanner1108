import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../models/store.dart';
import '../../models/meal_plan.dart';
import '../../theme/app_theme.dart';

class PlanConfigScreen extends StatefulWidget {
  const PlanConfigScreen({super.key});

  @override
  State<PlanConfigScreen> createState() => _PlanConfigScreenState();
}

class _PlanConfigScreenState extends State<PlanConfigScreen> {
  Store? _selectedStore;
  int _durationDays = 5;
  int _mealsPerDay = 3;
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

    final request = MealPlanGenerateRequest(
      storeId: _selectedStore!.id,
      durationDays: _durationDays,
      mealsPerDay: _selectedMealTypes.length,
      maxBudget: maxBudget,
      targetKcal: targetKcal,
      preferences: {
        'meal_types': _selectedMealTypes.toList(),
      },
    );

    final mealPlanProvider = Provider.of<MealPlanProvider>(context, listen: false);
    final success = await mealPlanProvider.generatePlan(request);

    if (mounted) {
      if (success) {
        Navigator.of(context).pushReplacementNamed('/plan/view');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mealPlanProvider.errorMessage ?? 'Nie udało się wygenerować planu'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final mealPlanProvider = Provider.of<MealPlanProvider>(context);

    // Domyślne mapowanie wyświetlania posiłków dla danej liczby posiłków dziennie
    final mealTypesInfo = {
      2: 'śniadanie, obiad',
      3: 'śniadanie, obiad, kolacja',
      4: 'śniadanie, obiad, kolacja, przekąska',
      5: 'śniadanie, obiad, kolacja, 2x przekąska',
    };

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
                  decoration: const BoxDecoration(
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
                      const Padding(
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
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['śniadanie', 'obiad', 'kolacja', 'przekąska'].map((type) {
                      final isSelected = _selectedMealTypes.contains(type);
                      final emoji = {
                        'śniadanie': '🌅',
                        'obiad': '☀️',
                        'kolacja': '🌙',
                        'przekąska': '🍎',
                      }[type] ?? '🍽️';
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
                  child: Text(mealPlanProvider.isGenerating ? 'Generowanie...' : 'Wygeneruj plan! 🍳'),
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
                    const Text(
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
