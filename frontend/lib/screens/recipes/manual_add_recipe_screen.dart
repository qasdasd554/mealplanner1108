import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/barcode_lookup_result.dart';
import '../../models/product.dart';
import '../../services/product_name_lookup_service.dart';
import '../../utils/quantity_formatter.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_amount_picker.dart';
import '../../widgets/product_label_recognition_sheet.dart';
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

  // Stałe węzły fokusu są celowe. Na części urządzeń z Gboard Flutter
  // potrafi zgubić fokus po zatwierdzeniu słowa (szczególnie wpisanego
  // gestem), przez co klawiatura znika mimo że użytkownik nadal edytuje
  // pole. Bez jawnych FocusNode nie da się bezpiecznie rozpoznać ani
  // naprawić takiego zdarzenia.
  final _nameFocus = FocusNode(debugLabel: 'recipeName');
  final _descriptionFocus = FocusNode(debugLabel: 'recipeDescription');
  final _prepTimeFocus = FocusNode(debugLabel: 'recipePrepTime');
  final _cookTimeFocus = FocusNode(debugLabel: 'recipeCookTime');
  final _servingsFocus = FocusNode(debugLabel: 'recipeServings');
  final Map<FocusNode, DateTime> _lastEditAt = {};
  final Set<FocusNode> _disposedFocusNodes = {};
  Timer? _focusRecoveryTimer;
  bool _allowPop = false;
  bool _isConfirmingDiscard = false;

  String _mealType = 'obiad';
  String _difficulty = 'łatwy';
  bool _requestPublic = false;
  bool _isSubmitting = false;

  final List<_IngredientRow> _ingredients = [];
  final List<TextEditingController> _stepControllers = [
    TextEditingController(),
  ];
  final List<FocusNode> _stepFocusNodes = [
    FocusNode(debugLabel: 'recipeStep1'),
  ];

  final List<String> _mealTypes = [
    'śniadanie',
    'obiad',
    'kolacja',
    'przekąska',
    'deser',
  ];
  final List<String> _difficulties = ['łatwy', 'średni', 'trudny'];

  Iterable<FocusNode> get _allFocusNodes sync* {
    yield _nameFocus;
    yield _descriptionFocus;
    yield _prepTimeFocus;
    yield _cookTimeFocus;
    yield _servingsFocus;
    yield* _stepFocusNodes;
  }

  @override
  void initState() {
    super.initState();
    for (final node in _allFocusNodes) {
      _watchImeFocus(node);
    }
  }

  void _watchImeFocus(FocusNode node) {
    node.addListener(() => _recoverUnexpectedImeFocusLoss(node));
  }

  void _recordEdit(FocusNode node) {
    _lastEditAt[node] = DateTime.now();
  }

  void _recoverUnexpectedImeFocusLoss(FocusNode node) {
    if (defaultTargetPlatform != TargetPlatform.android ||
        _disposedFocusNodes.contains(node) ||
        node.hasFocus) {
      return;
    }
    final editedAt = _lastEditAt[node];
    if (editedAt == null) return;

    // Po zmianie fokusu Flutter najpierw informuje poprzednie pole, a
    // dopiero potem ustawia następne. Krótkie opóźnienie pozwala odróżnić
    // prawidłowe przejście do innego pola od błędu Gboard, po którym żadne
    // pole nie jest aktywne.
    _focusRecoveryTimer?.cancel();
    _focusRecoveryTimer = Timer(const Duration(milliseconds: 80), () {
      _focusRecoveryTimer = null;
      if (!mounted ||
          _allowPop ||
          _isSubmitting ||
          _disposedFocusNodes.contains(node) ||
          node.hasFocus) {
        return;
      }
      if (DateTime.now().difference(editedAt) > const Duration(seconds: 1)) {
        return;
      }
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      final primary = FocusManager.instance.primaryFocus;
      if (primary != null && primary is! FocusScopeNode) return;
      node.requestFocus();
    });
  }

  bool get _hasUnsavedChanges =>
      _nameController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _prepTimeController.text.trim().isNotEmpty ||
      _cookTimeController.text.trim().isNotEmpty ||
      _servingsController.text.trim() != '2' ||
      _ingredients.isNotEmpty ||
      _stepControllers.any((controller) => controller.text.trim().isNotEmpty) ||
      _requestPublic;

  Future<void> _handleBackAttempt() async {
    if (_allowPop || _isConfirmingDiscard || !mounted) return;
    _isConfirmingDiscard = true;
    var discard = !_hasUnsavedChanges;
    if (!discard) {
      discard =
          await showDialog<bool>(
            context: context,
            builder:
                (dialogContext) => AlertDialog(
                  title: const Text('Odrzucić zmiany?'),
                  content: const Text(
                    'Wpisane dane przepisu nie zostały jeszcze zapisane.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Zostań'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Odrzuć'),
                    ),
                  ],
                ),
          ) ??
          false;
    }
    _isConfirmingDiscard = false;
    if (!discard || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _focusRecoveryTimer?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    for (final c in _stepControllers) {
      c.dispose();
    }
    final focusNodes = _allFocusNodes.toList(growable: false);
    _disposedFocusNodes.addAll(focusNodes);
    for (final node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _addIngredient() async {
    var selected = await showModalBottomSheet<BarcodeLookupResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceColor,
      builder: (ctx) => const _ProductPickerSheet(),
    );
    if (selected == null || !mounted) return;

    // Sama nazwa produktu nie wystarcza do policzenia przepisu. Wcześniej
    // brakujące pola były zamieniane na zera, przez co gotowy przepis mógł
    // pokazywać fałszywe 0 kcal. Jeśli znamy EAN, prowadzimy użytkownika do
    // uzupełnienia etykiety; bez EAN blokujemy zapis i wyjaśniamy, co zrobić.
    if (!selected.hasCompleteNutrition) {
      final barcode = selected.barcode?.trim();
      if (barcode != null && barcode.isNotEmpty) {
        final recognized = await showProductLabelRecognitionSheet(
          context,
          barcode: barcode,
        );
        if (!mounted || recognized == null) return;
        selected = recognized;
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 4),
              content: Text(
                'Ten produkt nie ma pełnych wartości odżywczych. '
                'Wybierz inny wynik albo dodaj produkt do bazy z danymi z etykiety.',
              ),
            ),
          );
        return;
      }
    }

    final preview = Product(
      id: selected.existingProductId ?? '',
      name: selected.name ?? '',
      brand: selected.brand,
      unit: selected.unit,
      defaultQuantity: 1,
      servingQuantity: selected.servingQuantity,
      nutritionPer100: NutritionInfo(
        kcal: selected.kcalPer100 ?? 0,
        protein: selected.proteinPer100 ?? 0,
        fat: selected.fatPer100 ?? 0,
        carbs: selected.carbsPer100 ?? 0,
        fiber: 0,
      ),
    );
    final amount = await showProductAmountPicker(
      context,
      product: preview,
      initialUnit: selected.servingQuantity != null ? 'opak' : selected.unit,
    );
    if (amount == null || !mounted) return;

    try {
      final product = await _productLookupService.resolveForRecipe(selected);
      if (!mounted) return;
      setState(
        () => _ingredients.add(
          _IngredientRow(
            product: product,
            quantity: amount.quantity,
            unit: amount.measure.code,
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

  void _addStep() {
    final focusNode = FocusNode(
      debugLabel: 'recipeStep${_stepFocusNodes.length + 1}',
    );
    _watchImeFocus(focusNode);
    setState(() {
      _stepControllers.add(TextEditingController());
      _stepFocusNodes.add(focusNode);
    });
  }

  void _removeStep(int index) {
    setState(() {
      _stepControllers[index].dispose();
      _stepControllers.removeAt(index);
      _disposedFocusNodes.add(_stepFocusNodes[index]);
      _lastEditAt.remove(_stepFocusNodes[index]);
      _stepFocusNodes[index].dispose();
      _stepFocusNodes.removeAt(index);
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
      _allowPop = true;
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
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBackAttempt());
      },
      child: Scaffold(
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
                  focusNode: _nameFocus,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _recordEdit(_nameFocus),
                  onFieldSubmitted: (_) => _descriptionFocus.requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'Nazwa przepisu',
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Podaj nazwę'
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  focusNode: _descriptionFocus,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => _recordEdit(_descriptionFocus),
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
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
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
                        decoration: const InputDecoration(
                          labelText: 'Trudność',
                        ),
                        items:
                            _difficulties
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
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
                        focusNode: _prepTimeFocus,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _recordEdit(_prepTimeFocus),
                        onFieldSubmitted: (_) => _cookTimeFocus.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Przygotowanie (min)',
                        ),
                      ),
                      TextFormField(
                        controller: _cookTimeController,
                        focusNode: _cookTimeFocus,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _recordEdit(_cookTimeFocus),
                        onFieldSubmitted: (_) => _servingsFocus.requestFocus(),
                        decoration: const InputDecoration(
                          labelText: 'Gotowanie (min)',
                        ),
                      ),
                      TextFormField(
                        controller: _servingsController,
                        focusNode: _servingsFocus,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _recordEdit(_servingsFocus),
                        onFieldSubmitted:
                            (_) => _stepFocusNodes.first.requestFocus(),
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
                      '${formatQuantity(ing.quantity, ing.unit)} ${formatUnitLabel(ing.unit)}',
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
                            focusNode: _stepFocusNodes[i],
                            maxLines: null,
                            textInputAction: TextInputAction.newline,
                            onChanged: (_) => _recordEdit(_stepFocusNodes[i]),
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
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Szukaj w katalogu i bazie produktów...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      _searchController.text.isEmpty
                          ? null
                          : IconButton(
                            tooltip: 'Wyczyść wyszukiwanie',
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                            icon: const Icon(Icons.close),
                          ),
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
                        : _results.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _searchController.text.trim().length < 2
                                  ? 'Wpisz co najmniej 2 znaki, aby znaleźć składnik.'
                                  : 'Nie znaleziono produktu. Dodaj go najpierw do bazy produktów wraz z wartościami z etykiety.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        )
                        : ListView.builder(
                          controller: scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final product = _results[index];
                            final hasNutrition = product.hasCompleteNutrition;
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
                                  if (!hasNutrition)
                                    product.barcode?.trim().isNotEmpty == true
                                        ? 'Wymaga uzupełnienia etykiety'
                                        : 'Brak pełnych wartości odżywczych',
                                ].join(' · '),
                              ),
                              trailing:
                                  hasNutrition
                                      ? const Icon(Icons.chevron_right)
                                      : Icon(
                                        Icons.warning_amber_rounded,
                                        color:
                                            Theme.of(context).colorScheme.error,
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
