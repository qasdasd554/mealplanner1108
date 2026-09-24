import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/barcode_lookup_result.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/product_name_lookup_service.dart';
import '../../utils/quantity_formatter.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import 'recipe_detail_screen.dart';
import '../../utils/error_utils.dart';

class _IngredientRow {
  Product product;
  double quantity;
  String unit;
  _IngredientRow({
    required this.product,
    required this.quantity,
    required this.unit,
  });
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
  final ProductNameLookupService _productLookupService =
      ProductNameLookupService();

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
  final List<TextEditingController> _stepControllers = [
    TextEditingController(),
  ];

  final List<String> _mealTypes = [
    'śniadanie',
    'obiad',
    'kolacja',
    'przekąska',
    'deser',
  ];
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
    final selected = await showModalBottomSheet<BarcodeLookupResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const _ProductPickerSheet(),
    );
    if (selected == null || !mounted) return;

    final preview = Product(
      id: selected.existingProductId ?? '',
      name: selected.name ?? '',
      brand: selected.brand,
      unit: selected.unit,
      defaultQuantity: {'szt', 'kg', 'l'}.contains(selected.unit) ? 1 : 100,
      nutritionPer100: NutritionInfo(
        kcal: selected.kcalPer100 ?? 0,
        protein: selected.proteinPer100 ?? 0,
        fat: selected.fatPer100 ?? 0,
        carbs: selected.carbsPer100 ?? 0,
        fiber: 0,
      ),
    );
    final quantity = await _askQuantity(preview);
    if (quantity == null || !mounted) return;

    try {
      final product = await _productLookupService.resolveForRecipe(selected);
      if (!mounted) return;
      setState(
        () => _ingredients.add(
          _IngredientRow(
            product: product,
            quantity: quantity * _conversionFactor(selected.unit, product.unit),
            unit: product.unit,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
    }
  }

  /// Jednostki DOKŁADNIEJSZE niż podstawowa jednostka produktu z katalogu.
  ///
  /// NAPRAWA BRAKU PRECYZJI: produkt typu olej ma w katalogu jednostkę
  /// "l", więc pole przyjmowało WYŁĄCZNIE litry — żeby wpisać 50 ml,
  /// trzeba było policzyć w głowie i wpisać "0.05". Tu dajemy wybór
  /// jednostki, a wpisaną wartość przeliczamy na jednostkę bazową dopiero
  /// przy zapisie — backend (quantity_to_grams) i tak rozumie tylko
  /// "g"/"kg"/"ml"/"l"/"szt", więc konwersja musi się odbyć po stronie
  /// aplikacji.
  static const Map<String, List<String>> _preciserUnits = {
    'l': ['l', 'ml'],
    'kg': ['kg', 'g'],
  };

  /// Mnożnik przeliczający wpisaną wartość na jednostkę BAZOWĄ produktu
  /// (tę z katalogu, którą backend faktycznie rozpoznaje).
  double _conversionFactor(String fromUnit, String baseUnit) {
    if (fromUnit == baseUnit) return 1.0;
    if (fromUnit == 'ml' && baseUnit == 'l') return 0.001;
    if (fromUnit == 'g' && baseUnit == 'kg') return 0.001;
    if (fromUnit == 'l' && baseUnit == 'ml') return 1000;
    if (fromUnit == 'kg' && baseUnit == 'g') return 1000;
    return 1.0;
  }

  Future<double?> _askQuantity(Product product) async {
    final baseUnit = product.unit;
    final options = _preciserUnits[baseUnit] ?? [baseUnit];
    String selectedUnit = baseUnit;

    final controller = TextEditingController(
      text: formatQuantity(product.defaultQuantity, baseUnit),
    );

    final result = await showDialog<double>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: Text(product.name),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: controller,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: 'Ilość',
                              ),
                            ),
                          ),
                          if (options.length > 1) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedUnit,
                                decoration: const InputDecoration(
                                  labelText: 'Jedn.',
                                ),
                                items:
                                    options
                                        .map(
                                          (u) => DropdownMenuItem(
                                            value: u,
                                            child: Text(u),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setDialogState(() => selectedUnit = v);
                                },
                              ),
                            ),
                          ] else
                            Padding(
                              padding: const EdgeInsets.only(left: 10, top: 14),
                              child: Text(baseUnit),
                            ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Anuluj'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final raw = double.tryParse(
                          controller.text.replaceAll(',', '.'),
                        );
                        if (raw == null) {
                          Navigator.pop(ctx);
                          return;
                        }
                        // Przeliczamy TERAZ, na jednostkę bazową — reszta
                        // ekranu (i backend) nic o wyborze jednostki w tym
                        // oknie nie wie, dostaje już gotową liczbę w "l"/"kg".
                        final converted =
                            raw * _conversionFactor(selectedUnit, baseUnit);
                        Navigator.pop(ctx, converted);
                      },
                      child: const Text('Dodaj'),
                    ),
                  ],
                ),
          ),
    );
    return result;
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 3),
            content: Text('Dodaj przynajmniej jeden składnik'),
          ),
        );
      return;
    }
    final steps =
        _stepControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    if (steps.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 3),
            content: Text('Dodaj przynajmniej jeden krok przygotowania'),
          ),
        );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final recipe = await _recipeService.createRecipeManually(
        name: _nameController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        mealType: _mealType,
        difficulty: _difficulty,
        prepTimeMin: int.tryParse(_prepTimeController.text),
        cookTimeMin: int.tryParse(_cookTimeController.text),
        servings: int.tryParse(_servingsController.text) ?? 2,
        instructions: steps,
        ingredients:
            _ingredients
                .map(
                  (i) => {
                    'product_id': i.product.id,
                    'quantity': i.quantity,
                    'unit': i.unit,
                  },
                )
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e)),
          ),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj przepis ręcznie')),
      // UWAGA (naprawa — ten sam wzorzec błędu, w kolejnym miejscu):
      // Form(ListView(...)) bez SafeArea — mimo że to przewijana lista,
      // w trybie edge-to-edge KONIEC przewijania nie uwzględniał
      // bezpiecznego marginesu systemowego, więc przycisk "Zapisz
      // przepis" na samym dole mógł kończyć się częściowo pod paskiem
      // nawigacji Androida.
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nazwa przepisu'),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty) ? 'Podaj nazwę' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Krótki opis (opcjonalnie)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _mealType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Rodzaj posiłku',
                      ),
                      items:
                          _mealTypes
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _mealType = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Trudność'),
                      items:
                          _difficulties
                              .map(
                                (t) =>
                                    DropdownMenuItem(value: t, child: Text(t)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _difficulty = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = <Widget>[
                    TextFormField(
                      controller: _prepTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Przygotowanie (min)',
                      ),
                    ),
                    TextFormField(
                      controller: _cookTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Gotowanie (min)',
                      ),
                    ),
                    TextFormField(
                      controller: _servingsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Porcje'),
                    ),
                  ];
                  if (constraints.maxWidth < 480) {
                    return Column(
                      children: [
                        fields[0],
                        const SizedBox(height: 12),
                        fields[1],
                        const SizedBox(height: 12),
                        fields[2],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: 12),
                      Expanded(child: fields[1]),
                      const SizedBox(width: 12),
                      Expanded(child: fields[2]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // Składniki
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Składniki',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                  child: Text(
                    'Brak dodanych składników',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ..._ingredients.asMap().entries.map((entry) {
                final i = entry.key;
                final ing = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ing.product.name),
                  subtitle: Text(
                    '${formatQuantity(ing.quantity, ing.unit)} ${ing.unit}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.errorColor,
                    ),
                    onPressed: () => setState(() => _ingredients.removeAt(i)),
                  ),
                );
              }),
              const SizedBox(height: 20),

              // Kroki przygotowania
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Kroki przygotowania',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                          backgroundColor: AppTheme.primaryColor.withOpacity(
                            0.15,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: 'Opisz ten krok...',
                          ),
                        ),
                      ),
                      if (_stepControllers.length > 1)
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
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
                  border: Border.all(
                    color: AppTheme.textSecondary.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.public, color: AppTheme.secondaryColor),
                    const SizedBox(width: 12),
                    // NAPRAWA błędu builda: AppTheme.textSecondary jest
                    // getterem zależnym od trybu jasny/ciemny (nie
                    // static const), więc ten poddrzewo NIE MOŻE być const
                    // — inaczej kompilator odrzuca cały widget z błędem
                    // "invocation is not allowed in a constant expression".
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Zgłoś do wspólnego katalogu',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          // NAPRAWA: wcześniej dostępne tylko dla kont
                          // Premium — udział w cotygodniowym konkursie (ranking
                          // liczy WYŁĄCZNIE publiczne przepisy) miał być
                          // dostępny dla każdego, nie tylko Premium. Moderacja
                          // administratora nadal chroni katalog przed spamem.
                          Text(
                            'Po akceptacji administratora będzie widoczny dla wszystkich i policzy się do cotygodniowego konkursu.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _requestPublic,
                      onChanged: (v) => setState(() => _requestPublic = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child:
                    _isSubmitting
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Zapisz przepis'),
              ),
              const SizedBox(height: 20),
            ],
          ),
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
  final ProductNameLookupService _service = ProductNameLookupService();
  final TextEditingController _searchController = TextEditingController();
  List<BarcodeLookupResult> _results = [];
  bool _isSearching = false;
  String? _error;
  Timer? _debounce;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    _debounce?.cancel();
    final generation = ++_generation;
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await _service.search(query);
        if (!mounted || generation != _generation) return;
        setState(() {
          _results = results;
          _isSearching = false;
        });
      } catch (error) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _results = [];
          _isSearching = false;
          _error = friendlyError(error);
        });
      }
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
              Text(
                'Wybierz składnik',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Szukaj w katalogu i bazie produktów...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _search,
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    _isSearching
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        )
                        : _error != null
                        ? Center(
                          child: Text(_error!, textAlign: TextAlign.center),
                        )
                        : ListView.builder(
                          controller: scrollController,
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final product = _results[index];
                            return ListTile(
                              title: Text(product.name ?? ''),
                              subtitle: Text(
                                [
                                  if (product.brand?.isNotEmpty == true)
                                    product.brand!,
                                  if (product.kcalPer100 != null)
                                    '${product.kcalPer100!.toStringAsFixed(0)} kcal / 100 ${product.unit}',
                                  if (product.source == 'open_food_facts')
                                    'Open Food Facts',
                                ].join(' · '),
                              ),
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
