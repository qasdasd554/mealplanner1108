import 'package:flutter/material.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_photo.dart';

/// Wyniki dopasowania — przepisy posortowane od najlepiej pasujących do
/// tego, co użytkownik ma w domu. Pełne dopasowania ("możesz ugotować
/// teraz") są wyraźnie wyróżnione od tych, którym brakuje kilku rzeczy.
class IngredientMatchResultsScreen extends StatelessWidget {
  final List<RecipeMatch> matches;

  const IngredientMatchResultsScreen({super.key, required this.matches});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dopasowane przepisy')),
      body: SafeArea(
        child: matches.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'Nie znaleziono żadnego przepisu pasującego do wybranych składników.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final match = matches[index];
                  return _buildMatchCard(context, match);
                },
              ),
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, RecipeMatch match) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/recipe/detail', arguments: match.recipe),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: match.isFullMatch ? Border.all(color: AppTheme.primaryColor, width: 1.5) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 90,
              child: RecipePhoto(recipe: match.recipe, showAiBadge: false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      match.recipe.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (match.isFullMatch)
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Możesz ugotować teraz',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Brakuje: ${match.missingIngredientNames.join(", ")}',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
