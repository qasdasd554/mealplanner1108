import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/premium_screen.dart';
import '../services/recipe_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

/// Zwraca zmieniony przepis albo null, jeśli użytkownik zamknął okno.
Future<Recipe?> showAiRecipeEditSheet(BuildContext context, Recipe recipe) {
  return showModalBottomSheet<Recipe>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AiRecipeEditSheet(recipe: recipe),
  );
}

class _AiRecipeEditSheet extends StatefulWidget {
  final Recipe recipe;

  const _AiRecipeEditSheet({required this.recipe});

  @override
  State<_AiRecipeEditSheet> createState() => _AiRecipeEditSheetState();
}

class _AiRecipeEditSheetState extends State<_AiRecipeEditSheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final prompt = _controller.text.trim();
    if (prompt.length < 3 || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await RecipeService().editRecipeWithAi(
        widget.recipe.id,
        prompt,
      );
      if (!mounted) return;
      await context.read<AuthProvider>().loadProfile();
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points =
        context.watch<AuthProvider>().currentUser?.premiumPoints ?? 0;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dostosuj przepis z AI',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Napisz, co zmienić w „${widget.recipe.name}”. Możesz np. poprosić o wersję bez mleka albo dodać konkretny składnik.',
            ),
            const SizedBox(height: 12),
            Text(
              'Udana zmiana kosztuje 1 punkt premium. Masz: $points pkt.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_saving,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Co zmienić lub dodać?',
                hintText:
                    'Np. zamień kurczaka na tofu i zmień kroki przygotowania',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            ],
            const SizedBox(height: 12),
            if (points < 1)
              TextButton.icon(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  );
                },
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Kup punkty'),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving || points < 1 ? null : _submit,
                child:
                    _saving
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Zmień przepis · 1 pkt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
