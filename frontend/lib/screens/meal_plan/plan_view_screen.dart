import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/store_provider.dart';
import '../../models/meal_plan.dart';
import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/decorative_circles.dart';

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
                        ? Center(
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
                                leading: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: RecipePhoto(
                                    recipe: recipe,
                                    borderRadius: BorderRadius.circular(6),
                                    showAiBadge: false,
                                  ),
                                ),
                                title: Text(
                                  recipe.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${recipe.totalTimeMin} min • ${recipe.difficulty}',
                                  style: TextStyle(color: AppTheme.textSecondary),
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
    // Suma makroskładników "na osobę" dla wybranego dnia — dzielimy
    // wartości odżywcze CAŁEGO przepisu przez jego liczbę porcji (to
    // matematycznie to samo, co przypada na jedną osobę, niezależnie od
    // wielkości gospodarstwa domowego — patrz komentarz przy
    // _per_person_nutrition w backendzie, ten sam wzór).
    double totalKcal = 0, totalProtein = 0, totalFat = 0, totalCarbs = 0;
    for (final entry in entries) {
      final servings = entry.recipe.servings > 0 ? entry.recipe.servings : 1;
      totalKcal += entry.recipe.nutritionTotal.kcal / servings;
      totalProtein += entry.recipe.nutritionTotal.protein / servings;
      totalFat += entry.recipe.nutritionTotal.fat / servings;
      totalCarbs += entry.recipe.nutritionTotal.carbs / servings;
    }

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
                        // UWAGA (naprawa): wcześniej ekran zamykał się
                        // ZAWSZE, niezależnie od tego, czy usunięcie
                        // faktycznie się powiodło — błąd był cicho
                        // gubiony, więc plan zostawał, a użytkownik
                        // widział tylko "coś się zamknęło", bez żadnej
                        // informacji, że nic nie zostało usunięte.
                        final success = await mealPlanProvider.deletePlan(plan.id);
                        if (!mounted) return;
                        if (success) {
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                mealPlanProvider.errorMessage ?? 'Nie udało się usunąć planu',
                              ),
                            ),
                          );
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
      body: Stack(
        children: [
          const DecorativeCircles(),
          SafeArea(
        // UWAGA (naprawa — ten sam błąd, co w plan_config_screen.dart):
        // dolny panel akcji ("Zmień parametry"/"Zatwierdź plan"/"Przejdź
        // do zakupów") miał tylko sztywny margines 24px, bez SafeArea —
        // w trybie edge-to-edge mogło to wyglądać, jakby przyciski
        // częściowo chowały się pod systemowym paskiem nawigacji na
        // niektórych telefonach.
        child: Column(
        children: [
          // Podsumowanie makroskładników DLA WYBRANEGO DNIA — bez tego
          // nie było wcale widać, ile faktycznie wychodzi kalorii/makro
          // w wygenerowanym planie, mimo że backend już dobrze to liczy.
          Container(
            margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroStat('${totalKcal.round()}', 'kcal', AppTheme.primaryColor),
                _buildMacroStat('${totalProtein.round()}g', 'białko', AppTheme.secondaryColor),
                _buildMacroStat('${totalFat.round()}g', 'tłuszcz', const Color(0xFFE0A62E)),
                _buildMacroStat('${totalCarbs.round()}g', 'węgl.', const Color(0xFF3B82F6)),
              ],
            ),
          ).animate().fadeIn(),

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
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
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
                                      // Kcal na porcję (na osobę), spójnie z
                                      // resztą aplikacji — nie łączna wartość
                                      // dla całego ugotowanego przepisu.
                                      '⏱ ${entry.recipe.totalTimeMin} min • ${(entry.recipe.nutritionTotal.kcal / (entry.recipe.servings > 0 ? entry.recipe.servings : 1)).round()} kcal',
                                      style: TextStyle(
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
                    child: const Text('Przejdź do zakupów'),
                  ),
          ),
        ],
        ),
      ),
          ],
        ),
    );
  }

  Widget _buildMacroStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}
