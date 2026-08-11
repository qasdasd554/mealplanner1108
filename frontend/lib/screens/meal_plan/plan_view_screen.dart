import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/store_provider.dart';
import '../../models/meal_plan.dart';
import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';

class PlanViewScreen extends StatefulWidget {
  const PlanViewScreen({super.key});

  @override
  State<PlanViewScreen> createState() => _PlanViewScreenState();
}

class _PlanViewScreenState extends State<PlanViewScreen> {
  int _selectedDay = 1;
  final RecipeService _recipeService = RecipeService();
  List<Recipe> _swapRecipes = [];
  bool _isLoadingSwapRecipes = false;

  Future<void> _activatePlan(String planId) async {
    final mealPlanProvider = Provider.of<MealPlanProvider>(context, listen: false);
    final success = await mealPlanProvider.activatePlan(planId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan został zatwierdzony! Lista zakupów wygenerowana.'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mealPlanProvider.errorMessage ?? 'Wystąpił błąd'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Otwórz panel dolny do zamiany przepisu
  void _openSwapBottomSheet(MealPlanEntry entry, String planId) async {
    setState(() {
      _isLoadingSwapRecipes = true;
      _swapRecipes = [];
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (_isLoadingSwapRecipes) {
              // Załaduj alternatywne przepisy o tym samym typie posiłku
              _recipeService.getRecipes(mealType: entry.recipe.mealType).then((recipes) {
                if (mounted) {
                  setModalState(() {
                    // Wyklucz aktualny przepis
                    _swapRecipes = recipes.where((r) => r.id != entry.recipe.id).toList();
                    _isLoadingSwapRecipes = false;
                  });
                }
              });

              return const SizedBox(
                height: 300,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zamień: ${entry.recipe.name}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wybierz inny posiłek z kategorii: ${entry.recipe.mealType}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _swapRecipes.isEmpty
                        ? const Center(
                            child: Text(
                              'Brak dostępnych alternatywnych przepisów',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _swapRecipes.length,
                            itemBuilder: (context, index) {
                              final recipe = _swapRecipes[index];

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                leading: Text(
                                  recipe.mealTypeEmoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                                title: Text(
                                  recipe.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${recipe.totalTimeMin} min • ${recipe.difficulty}',
                                  style: const TextStyle(color: AppTheme.textSecondary),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(80, 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  onPressed: () async {
                                    Navigator.of(context).pop(); // Zamknij bottom sheet
                                    final mealPlanProvider =
                                        Provider.of<MealPlanProvider>(this.context, listen: false);
                                    
                                    final success = await mealPlanProvider.swapRecipe(
                                      planId: planId,
                                      entryId: entry.id,
                                      newRecipeId: recipe.id,
                                    );

                                    if (success && this.mounted) {
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Przepis został zamieniony!'),
                                          backgroundColor: AppTheme.primaryColor,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Wybierz', style: TextStyle(fontSize: 12)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealPlanProvider = Provider.of<MealPlanProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);

    final plan = mealPlanProvider.currentPlan;

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan posiłków')),
        body: const Center(
          child: Text('Nie znaleziono planu posiłków. Wygeneruj nowy plan.'),
        ),
      );
    }

    String getStoreName(String id) {
      try {
        return storeProvider.stores.firstWhere((s) => s.id == id).name;
      } catch (_) {
        return 'Sklep';
      }
    }

    final storeName = getStoreName(plan.storeId);
    final entries = plan.entriesForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Plan posiłków'),
            Text(
              storeName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
            onPressed: () {
              // Potwierdzenie usunięcia
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Usuń plan'),
                  content: const Text('Czy na pewno chcesz usunąć ten plan posiłków?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Anuluj'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await mealPlanProvider.deletePlan(plan.id);
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Usuń'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Pozioma lista dni (Dzień 1, Dzień 2...)
          Container(
            height: 60,
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: plan.durationDays,
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = _selectedDay == day;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Dzień $day',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Lista posiłków dla wybranego dnia
          Expanded(
            child: mealPlanProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/recipe/detail',
                            arguments: entry.recipe,
                          );
                        },
                        onLongPress: () => _openSwapBottomSheet(entry, plan.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                entry.recipe.mealTypeEmoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.mealSlot.toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.recipe.name,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontSize: 16,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '⏱️ ${entry.recipe.totalTimeMin} min • 🔥 ${entry.recipe.nutritionTotal.kcal.toInt()} kcal',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.swap_horiz, color: AppTheme.primaryColor),
                                onPressed: () => _openSwapBottomSheet(entry, plan.id),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
                    },
                  ),
          ),

          // 3. Dolny panel akcji
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: plan.status == 'draft'
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/plan/config');
                          },
                          child: const Text('Zmień parametry'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _activatePlan(plan.id),
                          child: const Text('Zatwierdź plan'),
                        ),
                      ),
                    ],
                  )
                : ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/shopping');
                    },
                    child: const Text('Przejdź do zakupów 🛒'),
                  ),
          ),
        ],
      ),
    );
  }
}
