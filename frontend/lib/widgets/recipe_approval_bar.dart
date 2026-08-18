import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  const RecipeApprovalBar({super.key, required this.recipe});

  @override
  State<RecipeApprovalBar> createState() => _RecipeApprovalBarState();
}

class _RecipeApprovalBarState extends State<RecipeApprovalBar> {
  final RecipeService _service = RecipeService();
  bool _isBusy = false;
  String? _resolvedAs;

  Future<void> _act(bool approve) async {
    setState(() => _isBusy = true);
    try {
      if (approve) {
        await _service.approveRecipe(widget.recipe.id);
      } else {
        await _service.rejectRecipe(widget.recipe.id);
      }
      if (!mounted) return;
      setState(() => _resolvedAs = approve ? 'public' : 'rejected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Przepis zaakceptowany' : 'Przepis odrzucony')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się wykonać akcji')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = Provider.of<AuthProvider>(context).currentUser?.isAdmin ?? false;
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
              const Icon(Icons.pending_actions, color: AppTheme.secondaryColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ten przepis czeka na Twoją akceptację do wspólnego katalogu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                  child: const Text('Odrzuć'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isBusy ? null : () => _act(true),
                  child: _isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Zaakceptuj'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
