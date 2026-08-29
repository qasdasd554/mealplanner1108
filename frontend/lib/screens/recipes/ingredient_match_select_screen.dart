import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/pantry_service.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import 'ingredient_match_results_screen.dart';
import 'pantry_screen.dart';
import '../profile/premium_screen.dart';

/// "Co ugotować z tego, co mam" (Premium) — źródłem składników jest
/// teraz Spiżarnia (trwała lista tego, co użytkownik ma w domu), nie
/// ręczne wyszukiwanie za każdym razem. Wszystko domyślnie zaznaczone —
/// "jedno dotknięcie = użyj całej spiżarni", z możliwością odznaczenia
/// tego, czego akurat nie chce się użyć w tym wyszukiwaniu.
class IngredientMatchSelectScreen extends StatefulWidget {
  const IngredientMatchSelectScreen({super.key});

  @override
  State<IngredientMatchSelectScreen> createState() => _IngredientMatchSelectScreenState();
}

class _IngredientMatchSelectScreenState extends State<IngredientMatchSelectScreen> {
  final PantryService _pantryService = PantryService();
  final RecipeService _recipeService = RecipeService();

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
      setState(() => _errorMessage = friendlyError(e));
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

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaznacz przynajmniej jeden składnik.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final matches = await _recipeService.matchByIngredients(_selectedIds.toList());
      if (!mounted) return;
      final usedNames = _pantryItems
          .where((i) => _selectedIds.contains(i.product.id))
          .map((i) => i.product.name)
          .toList();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IngredientMatchResultsScreen(
            matches: matches,
            usedProductNames: usedNames,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
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
    final hasPremiumAccess = Provider.of<AuthProvider>(context).currentUser?.hasPremiumAccess ?? false;
    if (!hasPremiumAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Co ugotować z tego, co mam')),
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
                child: const Icon(Icons.workspace_premium_outlined, size: 40, color: AppTheme.secondaryColor),
              ),
              const SizedBox(height: 24),
              Text(
                'Funkcja Premium',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Dopasowywanie przepisów do tego, co masz w spiżarni, jest dostępne dla kont z aktywną subskrypcją Premium.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  ),
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Zobacz Premium'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Co ugotować z tego, co mam'),
        actions: [
          IconButton(
            icon: const Icon(Icons.kitchen_outlined),
            tooltip: 'Zarządzaj spiżarnią',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantryScreen()),
              );
              // Po powrocie ze Spiżarni odśwież — mogło się coś zmienić.
              _loadPantry();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.textSecondary),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          OutlinedButton(onPressed: _loadPantry, child: const Text('Spróbuj ponownie')),
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
                              Icon(Icons.kitchen_outlined, size: 56, color: AppTheme.textSecondary),
                              const SizedBox(height: 16),
                              Text(
                                'Twoja spiżarnia jest pusta. Dodaj do niej produkty, które masz w domu, żeby dopasować przepisy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const PantryScreen()),
                                  );
                                  _loadPantry();
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Przejdź do spiżarni'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Zaznaczono ${_selectedIds.length} z ${_pantryItems.length}',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    if (_selectedIds.length == _pantryItems.length) {
                                      _selectedIds.clear();
                                    } else {
                                      _selectedIds
                                        ..clear()
                                        ..addAll(_pantryItems.map((i) => i.product.id));
                                    }
                                  }),
                                  child: Text(
                                    _selectedIds.length == _pantryItems.length
                                        ? 'Odznacz wszystko'
                                        : 'Zaznacz wszystko',
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
                                final isSelected = _selectedIds.contains(item.product.id);
                                return CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (_) => _toggle(item.product.id),
                                  title: Text(item.product.name),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  activeColor: AppTheme.primaryColor,
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isSubmitting ? null : _submit,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text('Szukaj przepisów (${_selectedIds.length})'),
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}
