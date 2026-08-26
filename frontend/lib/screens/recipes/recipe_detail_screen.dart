import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_comments_section.dart';
import '../../widgets/recipe_favorite_button.dart';
import '../../widgets/recipe_approval_bar.dart';
import '../../widgets/dish_shopping_list_button.dart';
import '../../widgets/recipe_delete_button.dart';
import '../../widgets/recipe_publish_button.dart';
import '../../widgets/recipe_photo.dart';
import '../../utils/quantity_formatter.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recipe = ModalRoute.of(context)!.settings.arguments as Recipe;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Premium Hero AppBar — prawdziwe zdjęcie AI na pełną
          // szerokość, jeśli dostępne; w przeciwnym razie (przepis bez
          // zdjęcia) zachowujemy poprzednie traktowanie z ilustracją
          // kategorii na gradientowym tle.
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: RecipeFavoriteButton(recipe: recipe, activeColor: Colors.redAccent),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              // UWAGA (naprawa — ten sam błąd co w karcie listy): sekcja
              // dubinowała logikę wyświetlania zdjęcia zamiast reużywać
              // RecipePhoto, i przy tym sprawdzała TYLKO realPhotoAsset —
              // całkowicie pomijając photoBase64. Przebudowane na
              // RecipePhoto (ta sama, poprawna logika fallbacku wszędzie
              // w aplikacji: realPhotoAsset -> photoBase64 ->
              // categoryImageAsset), więc plakietka "wygenerowane przez
              // AI" jest teraz też wbudowana w sam widget, bez dublowania.
              background: Stack(
                fit: StackFit.expand,
                children: [
                  RecipePhoto(recipe: recipe, showAiBadge: true),
                  // Delikatny gradient u dołu — poprawia czytelność
                  // przycisku "wstecz" i plakietki AI na jasnych zdjęciach.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.25)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                  // Znaczek "Nowość" — widoczny przez 14 dni od dodania,
                  // niezależnie od źródła (z zewnątrz czy od użytkownika).
                  if (recipe.isNew)
                    Positioned(
                      top: 50,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Nowość',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 1b. Pasek akceptacji/odrzucenia — widoczny TYLKO adminom,
          // TYLKO gdy przepis czeka na akceptację (visibility="pending").
          // Sam widget zwraca pusty SizedBox we wszystkich innych
          // przypadkach, więc bezpiecznie wstawiamy go bezwarunkowo.
          SliverToBoxAdapter(
            child: RecipeApprovalBar(recipe: recipe),
          ),

          // 1c. Przycisk "Lista zakupów na to danie" — funkcja Premium.
          // Sam widget zwraca pusty SizedBox dla kont bez dostępu premium.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DishShoppingListButton(recipe: recipe),
            ),
          ),

          // "Opublikuj przepis" — widoczny TYLKO dla właściciela
          // prywatnego przepisu. Zaraz nad "Usuń", żeby były razem.
          SliverToBoxAdapter(
            child: RecipePublishButton(recipe: recipe),
          ),

          // "Usuń przepis" — widoczny TYLKO dla właściciela. Sam widget
          // zwraca pusty SizedBox dla cudzych/oficjalnych przepisów.
          SliverToBoxAdapter(
            child: RecipeDeleteButton(recipe: recipe),
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
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoColumn(context, '⏱ Czas', '${recipe.totalTimeMin} min'),
                        _buildDivider(),
                        _buildInfoColumn(context, 'Porcje', '${recipe.servings} porcje'),
                        _buildDivider(),
                        _buildInfoColumn(context, 'Trudność', recipe.difficulty),
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
                  Text(
                    'na 1 porcję',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                            '${formatQuantity(ing.quantity, ing.unit)} ${ing.unit}${ing.kcal != null ? ' (${ing.kcal} kcal)' : ''}',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 28),

                  // Lifehack odmierzania porcji makaronu bez wagi
                  // kuchennej — pokazuje się dla KAŻDEGO przepisu
                  // zawierającego makaron jako składnik.
                  if (recipe.containsPasta) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, color: AppTheme.primaryColor, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lifehack: porcja makaronu bez wagi',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Chwyć suchy makaron w dwa palce, formując kółko — jeśli '
                                  'jego średnica odpowiada mniej więcej monecie 5 zł, to '
                                  'jedna porcja (ok. 80-100 g) na osobę.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Sposób przygotowania — wcześniej ta sekcja w ogóle nie
                  // istniała w aplikacji, mimo że backend/dane mogły
                  // zawierać instrukcje krok po kroku.
                  if (recipe.instructions.isNotEmpty) ...[
                    Text(
                      'Sposób przygotowania',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...recipe.instructions.asMap().entries.map((entry) {
                      final stepNumber = entry.key + 1;
                      final stepText = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$stepNumber',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  stepText,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 28),

                  // ── Proponowane przyprawy (opcjonalne) ────────────
                  if (recipe.suggestedSeasonings.isNotEmpty) ...[
                    Text(
                      'Możesz też dodać',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'opcjonalne przyprawy, żeby wzbogacić smak',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: recipe.suggestedSeasonings.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(color: AppTheme.accentColor, fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── Komentarze i zdjęcia (teraz w pełni działające) ──
                  RecipeCommentsSection(recipeId: recipe.id),
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
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Brak danych o wartościach odżywczych.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final nut = recipe.nutritionTotal!;
    // Wartości odżywcze przeliczone NA PORCJĘ — recipe.nutritionTotal
    // przechowuje sumę dla całego przepisu (wszystkich porcji razem),
    // a to nie jest to, czego ktoś się spodziewa patrząc na "Kalorie"
    // przy jednym daniu (tak samo jak etykieta żywieniowa zawsze podaje
    // wartość na porcję, a nie na cały garnek).
    final servings = recipe.servings > 0 ? recipe.servings : 1;
    final list = [
      {'label': 'Kalorie', 'val': '${(nut.kcal / servings).round()} kcal', 'color': AppTheme.accentColor},
      {'label': 'Białko', 'val': '${(nut.protein / servings).round()} g', 'color': Colors.blue},
      {'label': 'Tłuszcze', 'val': '${(nut.fat / servings).round()} g', 'color': Colors.orange},
      {'label': 'Węgle', 'val': '${(nut.carbs / servings).round()} g', 'color': AppTheme.primaryColor},
      {'label': 'Błonnik', 'val': '${(nut.fiber / servings).round()} g', 'color': Colors.green},
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
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
