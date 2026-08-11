import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recipe = ModalRoute.of(context)!.settings.arguments as Recipe;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Premium Hero AppBar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.secondaryColor.withOpacity(0.4),
                      AppTheme.backgroundColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        recipe.mealTypeEmoji,
                        style: const TextStyle(fontSize: 72),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Karta z detalami przepisu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tagi
                  if (recipe.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: recipe.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ).animate().fadeIn(),

                  const SizedBox(height: 12),
                  // Nazwa przepisu
                  Text(
                    recipe.name,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 8),
                  // Opis
                  if (recipe.description != null && recipe.description!.isNotEmpty) ...[
                    Text(
                      recipe.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 20),
                  ],

                  // Czas, Porcje, Trudność (Info Row)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoColumn(context, '⏱️ Czas', '${recipe.totalTimeMin} min'),
                        _buildDivider(),
                        _buildInfoColumn(context, '🍽️ Porcje', '${recipe.servings} porcje'),
                        _buildDivider(),
                        _buildInfoColumn(context, '📊 Trudność', recipe.difficulty),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 24),

                  // Wartości odżywcze
                  Text(
                    'Wartości odżywcze',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildNutritionGrid(recipe),
                  const SizedBox(height: 28),

                  // Składniki
                  Text(
                    'Składniki',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...recipe.ingredients.map((ing) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ing.productName ?? 'Składnik',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${ing.quantity} ${ing.unit}${ing.kcal != null ? ' (${ing.kcal} kcal)' : ''}',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: AppTheme.textSecondary.withOpacity(0.2));
  }

  Widget _buildNutritionGrid(Recipe recipe) {
    if (recipe.nutritionTotal == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Brak danych o wartościach odżywczych.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final nut = recipe.nutritionTotal!;
    final list = [
      {'label': 'Kalorie', 'val': '${nut.kcal.toInt()} kcal', 'color': AppTheme.accentColor},
      {'label': 'Białko', 'val': '${nut.protein.toInt()} g', 'color': Colors.blue},
      {'label': 'Tłuszcze', 'val': '${nut.fat.toInt()} g', 'color': Colors.orange},
      {'label': 'Węgle', 'val': '${nut.carbs.toInt()} g', 'color': AppTheme.primaryColor},
      {'label': 'Błonnik', 'val': '${nut.fiber.toInt()} g', 'color': Colors.green},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final color = item['color'] as Color;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item['label'] as String,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                item['val'] as String,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
