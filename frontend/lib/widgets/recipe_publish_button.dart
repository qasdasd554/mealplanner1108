import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../theme/app_theme.dart';

/// Przycisk "Opublikuj przepis" — widoczny TYLKO dla właściciela
/// PRYWATNEGO przepisu (recipe.isOwnRecipe && visibility == 'private').
/// Wysyła go do kolejki oczekującej na akceptację administratora —
/// dokładnie tak samo, jak przełącznik "Udostępnij społeczności" przy
/// tworzeniu przepisu, tylko już PO fakcie. Samodzielny widget: zwraca
/// pusty SizedBox, gdy nie ma zastosowania (przepis już publiczny,
/// czeka na przegląd, odrzucony, albo cudzy/oficjalny).
class RecipePublishButton extends StatefulWidget {
  final Recipe recipe;
  final ValueChanged<Recipe>? onPublished;

  const RecipePublishButton({super.key, required this.recipe, this.onPublished});

  @override
  State<RecipePublishButton> createState() => _RecipePublishButtonState();
}

class _RecipePublishButtonState extends State<RecipePublishButton> {
  final RecipeService _service = RecipeService();
  bool _isPublishing = false;

  Future<void> _confirmAndPublish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opublikować przepis?'),
        content: const Text(
          'Przepis trafi do kolejki oczekującej na akceptację administratora. '
          'Po zatwierdzeniu będzie widoczny dla wszystkich użytkowników aplikacji.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Opublikuj'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isPublishing = true);
    try {
      final updated = await _service.requestPublish(widget.recipe.id);
      if (!mounted) return;
      widget.onPublished?.call(updated);
      // UWAGA: ekran szczegółów przepisu jest StatelessWidget (recipe
      // przychodzi jako finalne pole z zewnątrz), więc nie da się tu
      // lokalnie odświeżyć odznaki widoczności. Wracamy do listy —
      // ta i tak odświeża się przy powrocie i pokaże already-aktualny
      // stan (podobnie jak przy usuwaniu przepisu).
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Przepis zgłoszony — czeka na akceptację administratora.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się opublikować przepisu.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.recipe.isOwnRecipe || widget.recipe.visibility != 'private') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isPublishing ? null : _confirmAndPublish,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          icon: _isPublishing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.public, size: 18),
          label: const Text('Opublikuj przepis'),
        ),
      ),
    );
  }
}
