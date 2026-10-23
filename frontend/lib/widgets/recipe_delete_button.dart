import 'package:flutter/material.dart';
import '../l10n/market_locale.dart';
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
      builder:
          (ctx) => AlertDialog(
            title: Text(context.strings.detailDeleteTitle),
            content: Text(
              widget.recipe.visibility == 'public'
                  ? context.strings.detailDeletePublicHelp
                  : context.strings.detailDeleteHelp,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.strings.planCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.strings.planDelete),
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(context.strings.detailDeleteFailed),
          ),
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
          icon:
              _isDeleting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.errorColor,
                    ),
                  )
                  : const Icon(Icons.delete_outline, size: 18),
          label: Text(context.strings.detailDelete),
        ),
      ),
    );
  }
}
