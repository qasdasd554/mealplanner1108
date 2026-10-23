import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/market_locale.dart';
import '../models/recipe.dart';
import '../providers/auth_provider.dart';
import '../services/recipe_service.dart';
import '../theme/app_theme.dart';

/// Pasek "Zaakceptuj / Odrzuć" widoczny TYLKO administratorom, TYLKO gdy
/// przepis czeka na akceptację (visibility == "pending"). Zwykli
/// użytkownicy (w tym autor przepisu) nigdy tego nie widzą — to czysto
/// narzędzie moderacyjne.
class RecipeApprovalBar extends StatefulWidget {
  final Recipe recipe;

  const RecipeApprovalBar({super.key, required this.recipe, this.service});

  final RecipeService? service;

  @override
  State<RecipeApprovalBar> createState() => _RecipeApprovalBarState();
}

class _RecipeApprovalBarState extends State<RecipeApprovalBar> {
  late final RecipeService _service = widget.service ?? RecipeService();
  bool _isBusy = false;
  String? _resolvedAs;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant RecipeApprovalBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipe.id != widget.recipe.id) {
      _generation++;
      _isBusy = false;
      _resolvedAs = null;
    }
  }

  Future<void> _act(bool approve) async {
    if (_isBusy || _resolvedAs != null) return;
    final generation = _generation;
    setState(() => _isBusy = true);
    try {
      if (approve) {
        await _service.approveRecipe(widget.recipe.id);
      } else {
        await _service.rejectRecipe(widget.recipe.id);
      }
      if (!mounted || generation != _generation) return;
      setState(() => _resolvedAs = approve ? 'public' : 'rejected');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              approve
                  ? context.strings.approvalRecipeApproved
                  : context.strings.approvalRecipeRejected,
            ),
          ),
        );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(context.strings.approvalRecipeFailed),
          ),
        );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        Provider.of<AuthProvider>(context).currentUser?.isAdmin ?? false;
    final currentVisibility = _resolvedAs ?? widget.recipe.visibility;

    if (!isAdmin || currentVisibility != 'pending') {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions,
                color: AppTheme.secondaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.strings.approvalRecipePending,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isBusy ? null : () => _act(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                  child: Text(context.strings.adminReject),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isBusy ? null : () => _act(true),
                  child:
                      _isBusy
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(context.strings.approvalRecipeApprove),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
