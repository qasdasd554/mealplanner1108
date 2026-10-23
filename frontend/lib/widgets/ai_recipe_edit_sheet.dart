import 'package:flutter/material.dart';
import '../l10n/market_locale.dart';
import '../l10n/recipe_content.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/auth_provider.dart';
import '../screens/profile/premium_screen.dart';
import '../services/recipe_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

/// Zwraca zmieniony przepis albo null, jeśli użytkownik zamknął okno.
Future<Recipe?> showAiRecipeEditSheet(
  BuildContext context,
  Recipe recipe, {
  RecipeService? service,
}) {
  return showModalBottomSheet<Recipe>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AiRecipeEditSheet(recipe: recipe, service: service),
  );
}

class _AiRecipeEditSheet extends StatefulWidget {
  final Recipe recipe;
  final RecipeService? service;

  const _AiRecipeEditSheet({required this.recipe, this.service});

  @override
  State<_AiRecipeEditSheet> createState() => _AiRecipeEditSheetState();
}

class _AiRecipeEditSheetState extends State<_AiRecipeEditSheet> {
  late final RecipeService _service = widget.service ?? RecipeService();
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
      final updated = await _service.editRecipeWithAi(widget.recipe.id, prompt);
      if (!mounted) return;
      await context.read<AuthProvider>().loadProfile();
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (mounted)
        setState(() => _error = friendlyError(error, strings: context.strings));
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
              context.strings.aiEditTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.strings.aiEditIntro(widget.recipe.displayName(context)),
            ),
            const SizedBox(height: 12),
            Text(
              context.strings.aiEditCost(points),
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
              decoration: InputDecoration(
                labelText: context.strings.aiEditPromptLabel,
                hintText: context.strings.aiEditPromptHint,
                border: const OutlineInputBorder(),
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
                label: Text(context.strings.aiEditBuyPoints),
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
                        : Text(context.strings.aiEditSubmit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
