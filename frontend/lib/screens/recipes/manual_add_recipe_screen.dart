import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_search_service.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import 'recipe_detail_screen.dart';
import 'ai_add_recipe_screen.dart';
import '../../widgets/premium_feature_tag.dart';

class _IngredientRow {
  Product product;
  double quantity;
  String unit;
  _IngredientRow({required this.product, required this.quantity, required this.unit});
}

/// Ręczne dodawanie przepisu — pełny formularz (nazwa, składniki, kroki
/// przygotowania), na wzór ręcznego dodawania wpisu w Śledzeniu kalorii.
/// Utworzony przepis jest domyślnie PRYWATNY (widoczny tylko dla Ciebie).
/// Konta Premium mogą dodatkowo zgłosić przepis do wspólnego katalogu —
/// wymaga to akceptacji administratora, zanim stanie się widoczny dla
/// wszystkich.
class ManualAddRecipeScreen extends StatefulWidget {
  const ManualAddRecipeScreen({super.key});

  @override
  State<ManualAddRecipeScreen> createState() => _ManualAddRecipeScreenState();
}

class _ManualAddRecipeScreenState extends State<ManualAddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final RecipeService _recipeService = RecipeService();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController(text: '2');

  String _mealType = 'obiad';
  String _difficulty = 'łatwy';
  bool _requestPublic = false;
  bool _isSubmitting = false;

  final List<_IngredientRow> _ingredients = [];
  final List<TextEditingController> _stepControllers = [TextEditingController()];

  final List<String> _mealTypes = ['śniadanie', 'obiad', 'kolacja', 'przekąska'];
  final List<String> _difficulties = ['łatwy', 'średni', 'trudny'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    for (final c in _stepControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _ProductPickerSheet(),
    );
    if (selected == null || !mounted) return;

    final quantity = await _askQuantity(selected);
    if (quantity == null) return;

    setState(() {
      _ingredients.add(_IngredientRow(product: selected, quantity: quantity, unit: selected.unit));
    });
  }

  Future<double?> _askQuantity(Product product) async {
    final controller = TextEditingController(text: product.defaultQuantity.toStringAsFixed(0));
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Ilość (${product.unit})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(ctx, val);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
  }

  void _addStep() {
    setState(() => _stepControllers.add(TextEditingController()));
  }

  void _removeStep(int index) {
    setState(() {
      _stepControllers[index].dispose();
      _stepControllers.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dodaj przynajmniej jeden składnik')),
      );
      return;
    }
    final steps = _stepControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dodaj przynajmniej jeden krok przygotowania')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final recipe = await _recipeService.createRecipeManually(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        mealType: _mealType,
        difficulty: _difficulty,
        prepTimeMin: int.tryParse(_prepTimeController.text),
        cookTimeMin: int.tryParse(_cookTimeController.text),
        servings: int.tryParse(_servingsController.text) ?? 2,
        instructions: steps,
        ingredients: _ingredients
            .map((i) => {'product_id': i.product.id, 'quantity': i.quantity, 'unit': i.unit})
            .toList(),
        requestPublic: _requestPublic,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(),
          settings: RouteSettings(arguments: recipe),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException:', '').trim())),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = Provider.of<AuthProvider>(context).currentUser?.hasPremiumAccess ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dodaj przepis ręcznie'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AiAddRecipeScreen()),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 4),
                const Text('Użyj AI'),
                if (!isPremium) ...[
                  const SizedBox(width: 6),
                  const PremiumFeatureTag(fontSize: 9),
                ],
              ],
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nazwa przepisu'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Podaj nazwę' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Krótki opis (opcjonalnie)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _mealType,
                    decoration: const InputDecoration(labelText: 'Rodzaj posiłku'),
                    items: _mealTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _mealType = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _difficulty,
                    decoration: const InputDecoration(labelText: 'Trudność'),
                    items: _difficulties.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _difficulty = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Przygotowanie (min)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Gotowanie (min)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Porcje'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Składniki
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Składniki', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Dodaj'),
                ),
              ],
            ),
            if (_ingredients.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Brak dodanych składników', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ..._ingredients.asMap().entries.map((entry) {
              final i = entry.key;
              final ing = entry.value;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ing.product.name),
                subtitle: Text('${ing.quantity.toStringAsFixed(0)} ${ing.unit}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                  onPressed: () => setState(() => _ingredients.removeAt(i)),
                ),
              );
            }),
            const SizedBox(height: 20),

            // Kroki przygotowania
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Kroki przygotowania', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Dodaj krok'),
                ),
              ],
            ),
            ..._stepControllers.asMap().entries.map((entry) {
              final i = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 14, right: 8),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                        child: Text('${i + 1}', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: null,
                        decoration: const InputDecoration(hintText: 'Opisz ten krok...'),
                      ),
                    ),
                    if (_stepControllers.length > 1)
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                        onPressed: () => _removeStep(i),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            // Udostępnianie publiczne — tylko Premium
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.textSecondary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.public,
                    color: isPremium ? AppTheme.secondaryColor : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Zgłoś do wspólnego katalogu',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          isPremium
                              ? 'Po akceptacji administratora będzie widoczny dla wszystkich.'
                              : 'Dostępne dla kont Premium — standardowe konta mogą dodawać przepisy tylko dla siebie.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _requestPublic,
                    onChanged: isPremium ? (v) => setState(() => _requestPublic = v) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Zapisz przepis'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final ProductSearchService _service = ProductSearchService();
  final TextEditingController _searchController = TextEditingController();
  List<Product> _results = [];
  bool _isSearching = false;

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    final results = await _service.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wybierz produkt', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Szukaj produktu...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _search,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final product = _results[index];
                          return ListTile(
                            title: Text(product.name),
                            subtitle: product.brand != null ? Text(product.brand!) : null,
                            onTap: () => Navigator.of(context).pop(product),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
