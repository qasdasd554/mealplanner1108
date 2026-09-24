import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../theme/app_theme.dart';

/// Wynik edycji składników — wartości odżywcze po korektach użytkownika.
class EditedNutrition {
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  /// Czy użytkownik cokolwiek zmienił. Gdy nie, zapisujemy wartości
  /// oryginalne z przepisu, bez przeliczania — unika to drobnych różnic
  /// wynikających z zaokrągleń.
  final bool wasEdited;

  const EditedNutrition({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.wasEdited,
  });
}

/// Okno pozwalające skorygować składniki POJEDYNCZEGO wpisu w dzienniku.
///
/// WAŻNE: zmiany dotyczą WYŁĄCZNIE tego jednego wpisu w śledzeniu kalorii.
/// Sam przepis pozostaje nietknięty — to celowe. Użytkownik, który zjadł
/// danie bez sera albo z podwójną porcją ryżu, chce poprawić SWÓJ licznik
/// kalorii, a nie zmieniać przepis widoczny dla wszystkich (przy przepisach
/// oficjalnych nie miałby zresztą do tego prawa).
class EditIngredientsSheet extends StatefulWidget {
  final Recipe recipe;

  /// Mnożnik porcji wybrany wcześniej — wartości składników pokazujemy
  /// i przeliczamy już z jego uwzględnieniem, żeby liczby na ekranie
  /// odpowiadały temu, co użytkownik faktycznie zjadł.
  final double servingsFraction;

  const EditIngredientsSheet({
    super.key,
    required this.recipe,
    this.servingsFraction = 1.0,
  });

  @override
  State<EditIngredientsSheet> createState() => _EditIngredientsSheetState();
}

class _EditIngredientsSheetState extends State<EditIngredientsSheet> {
  /// Mnożnik ilości dla każdego składnika: 1.0 = tyle co w przepisie,
  /// 0.0 = pominięty. Trzymamy mnożniki, a nie ilości bezwzględne, bo
  /// dzięki temu przeliczenie działa tak samo niezależnie od jednostki
  /// (gramy, sztuki, łyżki).
  final Map<String, double> _multipliers = {};
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    for (final ing in widget.recipe.ingredients) {
      _multipliers[ing.id] = 1.0;
    }
  }

  /// Wartości odżywcze pojedynczego składnika przy zadanym mnożniku.
  ///
  /// NAPRAWA: odpowiedź API nigdy nie zawiera zagnieżdżonego obiektu
  /// `product` przy składnikach przepisu (tylko `product_id`/
  /// `product_name`) — więc gałąź licząca z `product.nutritionPer100`
  /// nigdy się nie wykonywała, a makroskładniki (poza kcal, liczonym
  /// osobno po stronie backendu) zawsze wychodziły zerowe. Backend
  /// liczy teraz protein/fat/carbs DLA TEJ ILOŚCI składnika w przepisie
  /// (tą samą funkcją, co kcal) i przysyła gotowe — więc to jest teraz
  /// GŁÓWNE źródło. Ścieżka przez `product` zostaje jako zabezpieczenie
  /// na przyszłość, gdyby API kiedyś zaczęło go dołączać.
  Map<String, double> _macrosFor(RecipeIngredient ing, double multiplier) {
    if (ing.protein != null ||
        ing.fat != null ||
        ing.carbs != null ||
        ing.kcal != null) {
      return {
        'kcal': (ing.kcal ?? 0).toDouble() * multiplier,
        'protein': (ing.protein ?? 0) * multiplier,
        'fat': (ing.fat ?? 0) * multiplier,
        'carbs': (ing.carbs ?? 0) * multiplier,
      };
    }

    final product = ing.product;
    if (product != null) {
      final grams = ing.quantity * multiplier;
      final per100 = product.nutritionPer100;
      final factor = grams / 100.0;
      return {
        'kcal': per100.kcal * factor,
        'protein': per100.protein * factor,
        'fat': per100.fat * factor,
        'carbs': per100.carbs * factor,
      };
    }
    return {'kcal': 0, 'protein': 0, 'fat': 0, 'carbs': 0};
  }

  Map<String, double> get _total {
    var kcal = 0.0, protein = 0.0, fat = 0.0, carbs = 0.0;
    for (final ing in widget.recipe.ingredients) {
      final m = _macrosFor(ing, _multipliers[ing.id] ?? 1.0);
      kcal += m['kcal']!;
      protein += m['protein']!;
      fat += m['fat']!;
      carbs += m['carbs']!;
    }
    final f = widget.servingsFraction;
    return {
      'kcal': kcal * f,
      'protein': protein * f,
      'fat': fat * f,
      'carbs': carbs * f,
    };
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dopasuj składniki',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Zmiany wpłyną tylko na ten wpis w Twoim liczniku kalorii. '
                    'Przepis pozostanie bez zmian.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.recipe.ingredients.length,
                itemBuilder: (context, index) {
                  final ing = widget.recipe.ingredients[index];
                  final mult = _multipliers[ing.id] ?? 1.0;
                  final excluded = mult == 0;
                  final macros = _macrosFor(ing, mult);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            excluded
                                ? AppTheme.textSecondary.withOpacity(0.2)
                                : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ing.productName ?? 'Składnik',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  decoration:
                                      excluded
                                          ? TextDecoration.lineThrough
                                          : null,
                                  color:
                                      excluded
                                          ? AppTheme.textSecondary
                                          : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                excluded
                                    ? 'pominięty'
                                    : '${(ing.quantity * mult).toStringAsFixed(0)} ${ing.unit}'
                                        ' · ${macros['kcal']!.round()} kcal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Skok co 0,25 zamiast dowolnej wartości: typowe
                        // korekty to "połowa", "półtora", "bez tego",
                        // a wpisywanie gramów z klawiatury przy każdym
                        // składniku byłoby mozolne.
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 20,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed:
                              mult <= 0
                                  ? null
                                  : () => setState(() {
                                    _multipliers[ing.id] = (mult - 0.25).clamp(
                                      0.0,
                                      5.0,
                                    );
                                    _touched = true;
                                  }),
                        ),
                        SizedBox(
                          width: 38,
                          child: Text(
                            excluded ? '—' : '${(mult * 100).round()}%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          visualDensity: VisualDensity.compact,
                          onPressed:
                              mult >= 5
                                  ? null
                                  : () => setState(() {
                                    _multipliers[ing.id] = (mult + 0.25).clamp(
                                      0.0,
                                      5.0,
                                    );
                                    _touched = true;
                                  }),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.textSecondary.withOpacity(0.15),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '${total['kcal']!.round()} kcal',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'B ${total['protein']!.round()}g · '
                          'T ${total['fat']!.round()}g · '
                          'W ${total['carbs']!.round()}g',
                          maxLines: 2,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          () => Navigator.of(context).pop(
                            EditedNutrition(
                              kcal: total['kcal']!,
                              protein: total['protein']!,
                              fat: total['fat']!,
                              carbs: total['carbs']!,
                              wasEdited: _touched,
                            ),
                          ),
                      child: const Text('Zapisz do dziennika'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
