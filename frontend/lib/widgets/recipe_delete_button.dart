import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../theme/app_theme.dart';

/// Przycisk "Usuń przepis" — widoczny TYLKO dla właściciela przepisu
/// (recipe.isOwnRecipe), nigdy dla oficjalnych 81 przepisów ani cudzych.
/// Samodzielny widget: zwraca pusty SizedBox, gdy nie ma zastosowania,
/// więc bezpiecznie wstawia się bezwarunkowo na ekranie szczegółów.
class RecipeDeleteButton extends StatefulWidget {
  final Recipe recipe;

  const RecipeDeleteButton({super.key, required this.recipe});

  @override
  State<RecipeDeleteButton> createState() => _RecipeDeleteButtonState();
}

class _RecipeDeleteButtonState extends State<RecipeDeleteButton> {
  final RecipeService _service = RecipeService();
  bool _isDeleting = false;

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć przepis?'),
        content: Text(
          widget.recipe.visibility == 'public'
              ? 'Ten przepis jest widoczny dla wszystkich — usunięcie go '
                  'usunie go też z list zakupów i planów innych osób, które '
                  'go używały. Tej operacji nie da się cofnąć.'
              : 'Tej operacji nie da się cofnąć.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _service.deleteRecipe(widget.recipe.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się usunąć przepisu')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.recipe.isOwnRecipe) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isDeleting ? null : _confirmAndDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
            side: const BorderSide(color: AppTheme.errorColor),
          ),
          icon: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.errorColor),
                )
              : const Icon(Icons.delete_outline, size: 18),
          label: const Text('Usuń przepis'),
        ),
      ),
    );
  }
}
