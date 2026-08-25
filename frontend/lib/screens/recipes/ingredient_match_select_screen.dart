import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/product_search_service.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import 'ingredient_match_results_screen.dart';

/// "Co ugotować z tego, co mam" (Premium) — użytkownik zaznacza produkty,
/// które ma aktualnie w domu, a aplikacja dopasowuje do nich przepisy z
/// katalogu (bez generowania nowych przez AI — tylko dopasowanie
/// istniejących, więc działa od razu i bez dodatkowego kosztu).
class IngredientMatchSelectScreen extends StatefulWidget {
  const IngredientMatchSelectScreen({super.key});

  @override
  State<IngredientMatchSelectScreen> createState() => _IngredientMatchSelectScreenState();
}

class _IngredientMatchSelectScreenState extends State<IngredientMatchSelectScreen> {
  final ProductSearchService _searchService = ProductSearchService();
  final RecipeService _recipeService = RecipeService();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _searchResults = [];
  final Map<String, Product> _selected = {};
  bool _isSearching = false;
  bool _isSubmitting = false;

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _searchService.search(query);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (_) {
      // Cicho ignorujemy błąd pojedynczego wyszukania — użytkownik może
      // po prostu spróbować ponownie wpisać frazę.
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _toggle(Product product) {
    setState(() {
      if (_selected.containsKey(product.id)) {
        _selected.remove(product.id);
      } else {
        _selected[product.id] = product;
      }
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaznacz przynajmniej jeden składnik, który masz w domu.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final matches = await _recipeService.matchByIngredients(_selected.keys.toList());
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => IngredientMatchResultsScreen(matches: matches)),
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Co ugotować z tego, co mam')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Szukaj produktu, np. "jajka"',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selected.values
                        .map((p) => Chip(
                              label: Text(p.name, style: const TextStyle(fontSize: 12)),
                              onDeleted: () => _toggle(p),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              _searchController.text.trim().length < 2
                                  ? 'Wpisz nazwę produktu, żeby go dodać do listy tego, co masz w domu.'
                                  : 'Brak wyników dla tej frazy.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final product = _searchResults[index];
                            final isSelected = _selected.containsKey(product.id);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) => _toggle(product),
                              title: Text(product.name),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: AppTheme.primaryColor,
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
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
                      : Text('Szukaj przepisów (${_selected.length})'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
