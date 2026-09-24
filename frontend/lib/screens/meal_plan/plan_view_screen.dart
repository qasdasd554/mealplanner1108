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

  Future<void> _activatePlan(String planId) async {
    final mealPlanProvider = Provider.of<MealPlanProvider>(
      context,
      listen: false,
    );
    final success = await mealPlanProvider.activatePlan(planId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 3),
              content: Text(
                'Plan został zatwierdzony! Lista zakupów wygenerowana.',
              ),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(mealPlanProvider.errorMessage ?? 'Wystąpił błąd'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
      }
    }
  }

  // Wyszukiwanie działa lokalnie w pobranej kategorii; Future powstaje
  // raz, więc wpisywanie tekstu nie wysyła kolejnych żądań do serwera.
  Future<void> _openSwapBottomSheet(MealPlanEntry entry, String planId) async {
    final searchController = TextEditingController();
    final recipesFuture = _recipeService.getRecipes(
      mealType: entry.recipe.mealType,
    );
    final picked = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (sheetContext, setSheetState) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                  ),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(sheetContext).height * 0.78,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Zamień: ${entry.recipe.name}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    Theme.of(sheetContext).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: searchController,
                                autofocus: true,
                                onChanged: (_) => setSheetState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Szukaj dania',
                                  hintText: 'Wpisz nazwę przepisu',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon:
                                      searchController.text.isEmpty
                                          ? null
                                          : IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              searchController.clear();
                                              setSheetState(() {});
                                            },
                                          ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: FutureBuilder<List<Recipe>>(
                            future: recipesFuture,
                            builder: (sheetContext, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return const Center(
                                  child: Text(
                                    'Nie udało się pobrać przepisów. Spróbuj ponownie.',
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              final needle =
                                  searchController.text.trim().toLowerCase();
                              final recipes =
                                  (snapshot.data ?? <Recipe>[])
                                      .where(
                                        (r) =>
                                            r.id != entry.recipe.id &&
                                            r.name.toLowerCase().contains(
                                              needle,
                                            ),
                                      )
                                      .toList();
                              if (recipes.isEmpty) {
                                return Center(
                                  child: Text(
                                    needle.isEmpty
                                        ? 'Brak innych dań w tej kategorii'
                                        : 'Nie znaleziono dania o tej nazwie',
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              return ListView.builder(
                                itemCount: recipes.length,
                                itemBuilder: (sheetContext, index) {
                                  final recipe = recipes[index];
                                  return ListTile(
                                    leading: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: RecipePhoto(
                                        recipe: recipe,
                                        borderRadius: BorderRadius.circular(6),
                                        showAiBadge: false,
                                      ),
                                    ),
                                    title: Text(recipe.name),
                                    subtitle: Text(
                                      '${recipe.totalTimeMin} min • ${recipe.difficulty}',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap:
                                        () => Navigator.of(
                                          sheetContext,
                                        ).pop(recipe),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    searchController.dispose();
    if (picked == null || !mounted) return;
    final provider = Provider.of<MealPlanProvider>(context, listen: false);
    final success = await provider.swapRecipe(
      planId: planId,
      entryId: entry.id,
      newRecipeId: picked.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          success
              ? 'Przepis został zamieniony'
              : provider.errorMessage ?? 'Nie udało się zamienić przepisu',
        ),
        backgroundColor: success ? AppTheme.primaryColor : AppTheme.errorColor,
      ),
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
                builder:
                    (context) => AlertDialog(
                      title: const Text('Usuń plan'),
                      content: const Text(
                        'Czy na pewno chcesz usunąć ten plan posiłków? '
                        'Na koncie standardowym usunięcie nie odnawia limitu '
                        'jednego nowego planu tygodniowo.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Anuluj'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            // UWAGA (naprawa): wcześniej ekran zamykał się
                            // ZAWSZE, niezależnie od tego, czy usunięcie
                            // faktycznie się powiodło — błąd był cicho
                            // gubiony, więc plan zostawał, a użytkownik
                            // widział tylko "coś się zamknęło", bez żadnej
                            // informacji, że nic nie zostało usunięte.
                            final success = await mealPlanProvider.deletePlan(
                              plan.id,
                            );
                            if (!mounted) return;
                            if (success) {
                              Navigator.of(context).pop();
                            } else {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 3),
                                    content: Text(
                                      mealPlanProvider.errorMessage ??
                                          'Nie udało się usunąć planu',
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
                      _buildMacroStat(
                        '${totalKcal.round()}',
                        'kcal',
                        AppTheme.primaryColor,
                      ),
                      _buildMacroStat(
                        '${totalProtein.round()}g',
                        'białko',
                        AppTheme.secondaryColor,
                      ),
                      _buildMacroStat(
                        '${totalFat.round()}g',
                        'tłuszcz',
                        const Color(0xFFE0A62E),
                      ),
                      _buildMacroStat(
                        '${totalCarbs.round()}g',
                        'węgl.',
                        const Color(0xFF3B82F6),
                      ),
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
                            color:
                                isSelected
                                    ? AppTheme.actionPrimaryColor
                                    : AppTheme.controlFillColor,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(16),
                            ),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? AppTheme.actionPrimaryColor
                                      : AppTheme.outlineColor,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Dzień $day',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 2. Lista posiłków dla wybranego dnia
                Expanded(
                  child:
                      mealPlanProvider.isLoading
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
                                    onLongPress:
                                        () => _openSwapBottomSheet(
                                          entry,
                                          plan.id,
                                        ),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(16),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: RecipePhoto(
                                              recipe: entry.recipe,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              showAiBadge: false,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  entry.mealSlot.toUpperCase(),
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.primaryColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.0,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  entry.recipe.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(fontSize: 16),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  // Kcal na porcję (na osobę), spójnie z
                                                  // resztą aplikacji — nie łączna wartość
                                                  // dla całego ugotowanego przepisu.
                                                  children: [
                                                    Icon(
                                                      Icons.schedule,
                                                      size: 14,
                                                      color:
                                                          AppTheme
                                                              .textSecondary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${entry.recipe.totalTimeMin} min • ${(entry.recipe.nutritionTotal.kcal / (entry.recipe.servings > 0 ? entry.recipe.servings : 1)).round()} kcal',
                                                      style: TextStyle(
                                                        color:
                                                            AppTheme
                                                                .textSecondary,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.swap_horiz,
                                              color: AppTheme.primaryColor,
                                            ),
                                            onPressed:
                                                () => _openSwapBottomSheet(
                                                  entry,
                                                  plan.id,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(delay: (index * 100).ms)
                                  .slideX(begin: 0.1, end: 0);
                            },
                          ),
                ),

                // 3. Dolny panel akcji
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child:
                      plan.status == 'draft'
                          ? Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(
                                      context,
                                    ).pushReplacementNamed('/plan/config');
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
