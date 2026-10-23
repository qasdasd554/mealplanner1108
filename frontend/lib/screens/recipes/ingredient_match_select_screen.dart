import 'package:flutter/material.dart';
import '../../l10n/market_locale.dart';
import '../../l10n/recipe_content.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/pantry_service.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import 'ai_add_recipe_screen.dart';
import 'ingredient_match_results_screen.dart';
import 'pantry_screen.dart';
import '../profile/premium_screen.dart';

/// "Co ugotować z tego, co mam" (Premium) — źródłem składników jest
/// teraz Spiżarnia (trwała lista tego, co użytkownik ma w domu), nie
/// ręczne wyszukiwanie za każdym razem. Wszystko domyślnie zaznaczone —
/// "jedno dotknięcie = użyj całej spiżarni", z możliwością odznaczenia
/// tego, czego akurat nie chce się użyć w tym wyszukiwaniu.
class IngredientMatchSelectScreen extends StatefulWidget {
  final PantryService? pantryService;
  final RecipeService? recipeService;
  const IngredientMatchSelectScreen({
    super.key,
    this.pantryService,
    this.recipeService,
  });

  @override
  State<IngredientMatchSelectScreen> createState() =>
      _IngredientMatchSelectScreenState();
}

class _IngredientMatchSelectScreenState
    extends State<IngredientMatchSelectScreen> {
  late final PantryService _pantryService =
      widget.pantryService ?? PantryService();
  late final RecipeService _recipeService =
      widget.recipeService ?? RecipeService();

  List<PantryItem> _pantryItems = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPantry();
  }

  Future<void> _loadPantry() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items = await _pantryService.getPantry();
      if (!mounted) return;
      setState(() {
        _pantryItems = items;
        // Domyślnie zaznacz WSZYSTKO — najczęstszy przypadek to "użyj
        // całej spiżarni", odznaczanie pojedynczych rzeczy to wyjątek.
        _selectedIds
          ..clear()
          ..addAll(items.map((i) => i.product.id));
      });
    } catch (e) {
      if (!mounted) return;
      // UWAGA (naprawa): pokazujemy PRAWDZIWY błąd zamiast po cichu
      // zostawiać pusty ekran — dokładnie ten problem zgłoszony wcześniej
      // ("po wpisaniu produktów nic nie pokazuje") wynikał z tego, że
      // poprzednia wersja tego ekranu całkowicie łykała błędy w ciszy.
      setState(
        () => _errorMessage = friendlyError(e, strings: context.strings),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggle(String productId) {
    setState(() {
      if (_selectedIds.contains(productId)) {
        _selectedIds.remove(productId);
      } else {
        _selectedIds.add(productId);
      }
    });
  }

  List<String> get _selectedProductNames =>
      _pantryItems
          .where((item) => _selectedIds.contains(item.product.id))
          .map((item) => item.product.displayName(context))
          .toList();

  bool _ensureAnythingSelected() {
    if (_selectedIds.isNotEmpty) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(context.strings.matchSelectOne),
        ),
      );
    return false;
  }

  Future<void> _openPantry({bool addProductImmediately = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PantryScreen(
              openAddOnStart: addProductImmediately,
              service: widget.pantryService,
            ),
      ),
    );
    if (mounted) await _loadPantry();
  }

  void _generateWithAi() {
    if (!_ensureAnythingSelected()) return;
    final ingredients = _selectedProductNames.join(', ');
    final prompt = context.strings.matchSelectPrompt(ingredients);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiAddRecipeScreen(initialText: prompt)),
    );
  }

  Future<void> _submit() async {
    if (!_ensureAnythingSelected()) return;
    // Keep the response and AI fallback tied to the same submitted selection.
    final submittedIds = _selectedIds.toList();
    final usedNames = _selectedProductNames;
    setState(() => _isSubmitting = true);
    try {
      final matches = await _recipeService.matchByIngredients(submittedIds);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => IngredientMatchResultsScreen(
                matches: matches,
                usedProductNames: usedNames,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // UWAGA (naprawa — "brak natychmiastowego komunikatu Premium"):
    // backend już poprawnie wymagał Premium (Depends(get_current_premium)
    // na /match-by-ingredients), ale ten ekran wcześniej NIE MIAŁ
    // żadnej bramki na wejściu — użytkownik bez Premium mógł swobodnie
    // przejść przez cały proces zaznaczania składników, dowiadując się
    // o braku uprawnień dopiero PO próbie wysłania. Teraz pokazujemy
    // to od razu, zanim w ogóle zobaczy formularz.
    final hasPremiumAccess =
        Provider.of<AuthProvider>(context).currentUser?.hasPremiumAccess ??
        false;
    if (!hasPremiumAccess) {
      return Scaffold(
        appBar: AppBar(title: Text(context.strings.matchTitle)),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  size: 40,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.strings.matchPremium,
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                context.strings.matchPremiumBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PremiumScreen(),
                        ),
                      ),
                  icon: const Icon(Icons.workspace_premium),
                  label: Text(context.strings.matchSeePremium),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.matchTitle)),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 48,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _loadPantry,
                          child: Text(context.strings.productsRetry),
                        ),
                      ],
                    ),
                  ),
                )
                : _pantryItems.isEmpty
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.kitchen_outlined,
                          size: 56,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.strings.matchEmptyPantry,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed:
                              () => _openPantry(addProductImmediately: true),
                          icon: const Icon(Icons.add),
                          label: Text(context.strings.matchAddPantry),
                        ),
                      ],
                    ),
                  ),
                )
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            context.strings.matchSelected(
                              _selectedIds.length,
                              _pantryItems.length,
                            ),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () => setState(() {
                                  if (_selectedIds.length ==
                                      _pantryItems.length) {
                                    _selectedIds.clear();
                                  } else {
                                    _selectedIds
                                      ..clear()
                                      ..addAll(
                                        _pantryItems.map((i) => i.product.id),
                                      );
                                  }
                                }),
                            child: Text(
                              _selectedIds.length == _pantryItems.length
                                  ? context.strings.matchDeselect
                                  : context.strings.matchSelectAll,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _pantryItems.length,
                        itemBuilder: (context, index) {
                          final item = _pantryItems[index];
                          final isSelected = _selectedIds.contains(
                            item.product.id,
                          );
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggle(item.product.id),
                            title: Text(item.product.displayName(context)),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppTheme.primaryColor,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child:
                                _isSubmitting
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : Text(
                                      context.strings.matchSearch(
                                        _selectedIds.length,
                                      ),
                                    ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _generateWithAi,
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: Text(
                              context.strings.matchGenerate,
                              maxLines: 2,
                              softWrap: true,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed:
                                () => _openPantry(addProductImmediately: true),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 18,
                            ),
                            label: Text(
                              context.strings.matchAddPantry,
                              maxLines: 2,
                              softWrap: true,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
