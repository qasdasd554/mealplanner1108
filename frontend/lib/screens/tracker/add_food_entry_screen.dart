import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/market_locale.dart';
import '../../l10n/recipe_content.dart';
import 'package:provider/provider.dart';

import '../../providers/food_log_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../models/meal_plan.dart';
import '../../models/food_log.dart';
import '../../models/barcode_lookup_result.dart';
import '../../services/api_client.dart';
import '../../services/product_name_lookup_service.dart';
import '../../l10n/catalog_labels.dart';
import '../../services/recipe_service.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edit_ingredients_sheet.dart';
import '../../widgets/submit_product_sheet.dart';
import '../../widgets/pick_product_from_catalog_sheet.dart';
import '../../widgets/product_name_autocomplete_field.dart';

double _pickedAmountValue(PickedCatalogProduct picked) => picked.quantity;

String _pickedAmountUnit(PickedCatalogProduct picked) => picked.unit;

class AddFoodEntryScreen extends StatefulWidget {
  final String? initialBarcode;
  final RecipeService? recipeService;
  final ApiClient? productClient;

  const AddFoodEntryScreen({
    super.key,
    this.initialBarcode,
    this.recipeService,
    this.productClient,
  });

  @override
  State<AddFoodEntryScreen> createState() => _AddFoodEntryScreenState();
}

class _AddFoodEntryScreenState extends State<AddFoodEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialBarcode == null ? 0 : 2,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.foodEntryTitle),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(text: context.strings.foodEntryFromPlan),
            Tab(text: context.strings.foodEntryFromRecipes),
            Tab(text: context.strings.foodEntryProducts),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _PlanTab(),
          _RecipesTab(service: widget.recipeService),
          _ProductsTab(
            initialBarcode: widget.initialBarcode,
            client: widget.productClient,
          ),
        ],
      ),
    );
  }
}

/// ── Zakładka "Z planu" ─────────────────────────────────────────────
/// Wcześniej ta zakładka była pustym tekstem "Wybierz posiłek ze swojego
/// planu" — nic tam nie działało. Teraz pokazuje pozycje z aktywnego planu
/// posiłków przypadające na dzisiaj i pozwala je jednym dotknięciem dodać
/// do dziennika (backend przelicza makra na podstawie przepisu).
class _PlanTab extends StatefulWidget {
  const _PlanTab();

  @override
  State<_PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<_PlanTab> {
  final List<String> _mealTypes = const [
    'Śniadanie',
    'Obiad',
    'Kolacja',
    'Przekąska',
    'Deser',
  ];

  /// Pokazuje krótki dialog wyboru liczby porcji przed zalogowaniem
  /// posiłku z planu — wcześniej "+" logował ZAWSZE dokładnie tyle porcji,
  /// ile było zapisane w planie, bez możliwości powiedzenia "zjadłem
  /// tylko połowę" albo "dołożyłem sobie".
  Future<void> _pickServingsAndLog(
    BuildContext context,
    FoodLogProvider provider,
    MealPlanEntry entry,
  ) async {
    double servings = 1.0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: Text(entry.recipe.displayName(context)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.strings.foodEntryServingsQuestion),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed:
                                servings > 0.5
                                    ? () => setDialogState(
                                      () =>
                                          servings = (servings - 0.5).clamp(
                                            0.5,
                                            10,
                                          ),
                                    )
                                    : null,
                          ),
                          Text(
                            servings.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed:
                                () => setDialogState(
                                  () =>
                                      servings = (servings + 0.5).clamp(
                                        0.5,
                                        10,
                                      ),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(context.strings.productsCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(context.strings.add),
                    ),
                  ],
                ),
          ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await provider.addFromMealPlanEntry(
      entry.id,
      servings: servings,
    );
    if (context.mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(
                provider.error ?? context.strings.foodEntryMealFailed,
              ),
            ),
          );
      }
    }
  }

  Future<void> _scanBarcodeAndLog(
    BuildContext context,
    FoodLogProvider provider,
  ) async {
    final picked = await showModalBottomSheet<PickedCatalogProduct>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PickProductFromCatalogSheet(scanOnOpen: true),
    );
    if (picked == null || !context.mounted) return;

    var mealType = 'Przekąska';
    final selectedType = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => AlertDialog(
                  title: Text(picked.name),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${picked.amountLabelFor(context.strings)} · '
                        '${picked.kcal.round()} kcal',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: mealType,
                        decoration: InputDecoration(
                          labelText: context.strings.foodEntryMealType,
                        ),
                        items:
                            _mealTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      context.strings.diaryMealTypeLabel(type),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => mealType = value);
                          }
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(context.strings.productsCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, mealType),
                      child: Text(context.strings.foodEntryAddDiary),
                    ),
                  ],
                ),
          ),
    );
    if (selectedType == null || !context.mounted) return;

    final success = await provider.addManualEntry(
      mealType: selectedType,
      foodName: picked.name,
      calories: picked.kcal,
      protein: picked.protein,
      carbs: picked.carbs,
      fat: picked.fat,
      amountValue: _pickedAmountValue(picked),
      amountUnit: _pickedAmountUnit(picked),
      portionSize: picked.portionSize,
      portionUnit: picked.portionUnit,
    );
    if (!context.mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              provider.error ?? context.strings.foodEntryProductFailed,
            ),
          ),
        );
    }
  }

  Widget _withBarcodeButton(
    BuildContext context,
    FoodLogProvider provider,
    Widget content,
  ) {
    return Column(
      children: [
        Expanded(child: content),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _scanBarcodeAndLog(context, provider),
                icon: const Icon(Icons.barcode_reader, size: 20),
                label: Text(context.strings.productsScan),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // UWAGA (naprawa): wcześniej ładowało dane TYLKO gdy lista była
      // pusta — nawet w ramach tej samej sesji, jeśli użytkownik wrócił
      // na ten ekran po zmianie planu (np. usunął stary, wygenerował
      // nowy), widział nieaktualne dane, dopóki coś innego nie wymusiło
      // odświeżenia. Teraz odświeża zawsze przy wejściu na ekran
      // (chyba że akurat trwa już inne ładowanie).
      final provider = Provider.of<MealPlanProvider>(context, listen: false);
      if (!provider.isLoading) {
        provider.loadPlans();
      }
    });
  }

  /// Numer dnia planu odpowiadający PODANEJ dacie (1-indeksowany, tak jak
  /// `day_number` w backendzie), przycięty do zakresu planu.
  ///
  /// UWAGA (naprawa): wcześniej ta funkcja zawsze liczyła względem
  /// `DateTime.now()` (dzisiaj), całkowicie ignorując datę aktualnie
  /// przeglądaną w ekranie śledzenia. Efekt: zakładka "Z planu" zawsze
  /// pokazywała DZISIEJSZE posiłki z planu, nawet gdy użytkownik cofnął
  /// się strzałkami na inny dzień — a zalogowanie takiego posiłku i tak
  /// zapisywało się pod dzisiejszą datą (bo tyle właśnie wynikało z dnia
  /// planu, który został pokazany).
  int? _dayNumberFor(
    DateTime targetDate,
    String? startDateStr,
    int durationDays,
  ) {
    if (startDateStr == null) return null;
    final start = DateTime.tryParse(startDateStr);
    if (start == null) return null;
    final startDay = DateTime(start.year, start.month, start.day);
    final targetDay = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );
    final diff =
        DateTime.utc(targetDay.year, targetDay.month, targetDay.day)
            .difference(
              DateTime.utc(startDay.year, startDay.month, startDay.day),
            )
            .inDays +
        1;
    if (diff < 1 || diff > durationDays) return null;
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    final mealPlanProvider = Provider.of<MealPlanProvider>(context);
    final foodLogProvider = Provider.of<FoodLogProvider>(context);
    final targetDate = foodLogProvider.currentDate;

    if (mealPlanProvider.isLoading) {
      return _withBarcodeButton(
        context,
        foodLogProvider,
        const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final selectedPlan = mealPlanProvider.currentPlan;
    final matchingPlans = mealPlanProvider.activePlans.where(
      (p) => p.dayNumberAt(targetDate) != null,
    );
    final plan =
        selectedPlan?.isInUseAt(DateTime.now()) == true &&
                selectedPlan?.dayNumberAt(targetDate) != null
            ? selectedPlan
            : matchingPlans.firstOrNull ?? mealPlanProvider.activePlan;
    if (plan == null) {
      return _withBarcodeButton(
        context,
        foodLogProvider,
        _EmptyHint(
          icon: Icons.calendar_today_outlined,
          text: context.strings.foodEntryNoPlan,
        ),
      );
    }

    final dayNumber = _dayNumberFor(
      targetDate,
      plan.startDate,
      plan.durationDays,
    );
    if (dayNumber == null) {
      return _withBarcodeButton(
        context,
        foodLogProvider,
        _EmptyHint(
          icon: Icons.event_busy_outlined,
          text: context.strings.foodEntryPlanDate(
            '${targetDate.day.toString().padLeft(2, '0')}.${targetDate.month.toString().padLeft(2, '0')}',
          ),
        ),
      );
    }

    final entries = plan.entriesForDay(dayNumber);
    if (entries.isEmpty) {
      return _withBarcodeButton(
        context,
        foodLogProvider,
        _EmptyHint(
          icon: Icons.no_meals_outlined,
          text: context.strings.foodEntryNoPlannedMeals,
        ),
      );
    }

    return _withBarcodeButton(
      context,
      foodLogProvider,
      ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.strings.diaryMealTypeLabel(
                          entry.mealSlot.isEmpty
                              ? ''
                              : entry.mealSlot[0].toUpperCase() +
                                  entry.mealSlot.substring(1),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.recipe.displayName(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                foodLogProvider.isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                    : IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                      tooltip: context.strings.foodEntryAddDiary,
                      onPressed:
                          () => _pickServingsAndLog(
                            context,
                            foodLogProvider,
                            entry,
                          ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ── Zakładka "Z przepisów" ─────────────────────────────────────────
/// Wcześniej pusty tekst "Wyszukaj z bazy przepisów" — bez pola wyszukiwania
/// i bez żadnej listy. Teraz przeszukuje bazę ~80 przepisów i pozwala dodać
/// wybrany do dziennika z podaniem liczby porcji.
class _RecipesTab extends StatefulWidget {
  final RecipeService? service;
  const _RecipesTab({this.service});

  @override
  State<_RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<_RecipesTab> {
  late final RecipeService _service;
  final TextEditingController _searchController = TextEditingController();
  List<Recipe> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RecipeService();
    _search('');
  }

  // UWAGA (naprawa): pole wcześniej wywoływało wyszukiwanie TYLKO po
  // wciśnięciu Enter/Gotowe na klawiaturze (onSubmitted) — w praktyce
  // wyglądało to jak "wyszukiwanie nie działa", bo nic się nie działo
  // podczas pisania, jak w każdym typowym polu wyszukiwania. Teraz
  // wyszukuje na bieżąco, z małym opóźnieniem (debounce), żeby nie
  // odpytywać serwera przy każdym pojedynczym znaku.
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _searchGeneration++;
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;
    setState(() => _loading = true);
    try {
      final results = await _service.getRecipes(
        search: query.isEmpty ? null : query,
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = results;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _error = context.strings.foodEntryRecipesFailed;
        _loading = false;
      });
    }
  }

  Future<void> _pickAndLog(Recipe recipe) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _LogRecipeSheet(recipe: recipe),
    );
    if (result == null || !mounted) return;

    final servings = result['servings'] as double;
    final mealType = result['mealType'] as String;
    final foodLogProvider = Provider.of<FoodLogProvider>(
      context,
      listen: false,
    );

    // Użytkownik wybrał "Dopasuj składniki" — otwieramy edycję i zapisujemy
    // WYLICZONE wartości zamiast tych z przepisu. Zmiana dotyczy tylko tego
    // wpisu w dzienniku; sam przepis zostaje nietknięty.
    if (result['editIngredients'] == true) {
      // Przepis z listy bywa uproszczony (bez składników), więc pobieramy
      // pełną wersję — bez niej nie ma czego edytować.
      Recipe full = recipe;
      if (recipe.ingredients.isEmpty) {
        try {
          full = await RecipeService().getRecipe(recipe.id);
        } catch (_) {
          // Nie udało się pobrać — zapisujemy normalnie, bez edycji.
        }
      }
      if (!mounted) return;

      if (full.ingredients.isNotEmpty) {
        final edited = await showModalBottomSheet<EditedNutrition>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: AppTheme.surfaceColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder:
              (_) => EditIngredientsSheet(
                recipe: full,
                servingsFraction:
                    servings / (full.servings > 0 ? full.servings : 1),
              ),
        );
        if (edited == null || !mounted) return;

        if (edited.wasEdited) {
          // Zapis jako wpis WŁASNY, nie powiązany z przepisem — bo
          // wartości odżywcze zostały skorygowane i nie odpowiadają już
          // temu, co jest w przepisie. Nazwa zostaje ta sama, więc
          // w dzienniku widać, co to było.
          final ok = await foodLogProvider.addManualEntry(
            mealType: mealType,
            foodName: full.name,
            calories: edited.kcal,
            protein: edited.protein,
            fat: edited.fat,
            carbs: edited.carbs,
          );
          if (!mounted) return;
          if (ok) {
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 3),
                  content: Text(
                    foodLogProvider.error ??
                        context.strings.foodEntryMealFailed,
                  ),
                ),
              );
          }
          return;
        }
        // Nic nie zmieniono — zapisujemy zwykłą ścieżką, żeby wpis
        // zachował powiązanie z przepisem.
      }
    }

    final success = await foodLogProvider.addRecipeEntry(
      recipeId: recipe.id,
      mealType: mealType,
      servings: servings,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              foodLogProvider.error ?? context.strings.foodEntryMealFailed,
            ),
          ),
        );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.strings.foodEntryRecipeSearch,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _search,
          ),
        ),
        Expanded(
          child:
              _loading
                  ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                  : _error != null
                  ? _EmptyHint(icon: Icons.error_outline, text: _error!)
                  : _results.isEmpty
                  ? _EmptyHint(
                    icon: Icons.search_off,
                    text: context.strings.foodEntryNoResults,
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final recipe = _results[index];
                      return Material(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _pickAndLog(recipe),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        recipe.displayName(context),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        // UWAGA (naprawa): recipe.nutritionTotal to
                                        // wartości dla CAŁEGO przepisu, nie na porcję —
                                        // trzeba podzielić przez recipe.servings, inaczej
                                        // dosłowny podpis "/ porcja" pokazywał wartość
                                        // 2-4x za wysoką. Zabezpieczenie przed servings=0
                                        // (Infinity.round() rzuca wyjątkiem w Dart).
                                        context.strings.foodEntryKcalServing(
                                          (recipe.nutritionTotal.kcal /
                                                  (recipe.servings > 0
                                                      ? recipe.servings
                                                      : 1))
                                              .round()
                                              .toString(),
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.add_circle_outline,
                                  color: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _LogRecipeSheet extends StatefulWidget {
  final Recipe recipe;
  const _LogRecipeSheet({required this.recipe});

  @override
  State<_LogRecipeSheet> createState() => _LogRecipeSheetState();
}

class _LogRecipeSheetState extends State<_LogRecipeSheet> {
  final List<String> _mealTypes = [
    'Śniadanie',
    'Obiad',
    'Kolacja',
    'Przekąska',
    'Deser',
  ];
  late String _mealType;
  double _servings = 1.0;

  @override
  void initState() {
    super.initState();
    _mealType = _mealTypes.firstWhere(
      (t) => t.toLowerCase() == widget.recipe.mealType.toLowerCase(),
      orElse: () => 'Obiad',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.recipe.displayName(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Text(
              context.strings.foodEntryMealType,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children:
                  _mealTypes.map((t) {
                    return ChoiceChip(
                      label: Text(context.strings.diaryMealTypeLabel(t)),
                      selected: _mealType == t,
                      selectedColor: AppTheme.primaryTintColor,
                      onSelected: (_) => setState(() => _mealType = t),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              context.strings.foodEntryServings,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed:
                      _servings > 0.5
                          ? () => setState(
                            () => _servings = (_servings - 0.5).clamp(0.5, 10),
                          )
                          : null,
                ),
                Text(
                  _servings.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed:
                      () => setState(
                        () => _servings = (_servings + 0.5).clamp(0.5, 10),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed:
                  () => Navigator.pop(context, {
                    'mealType': _mealType,
                    'servings': _servings,
                  }),
              child: Text(context.strings.foodEntryAddDiary),
            ),
            const SizedBox(height: 6),
            // Druga, opcjonalna ścieżka: skorygować składniki przed
            // zapisem. Celowo jako mniej wyeksponowany przycisk tekstowy —
            // to przypadek rzadszy niż zwykłe dodanie, a nie chcemy
            // komplikować typowej czynności.
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed:
                    () => Navigator.pop(context, {
                      'mealType': _mealType,
                      'servings': _servings,
                      'editIngredients': true,
                    }),
                icon: const Icon(Icons.tune, size: 18),
                label: Text(context.strings.foodEntryAdjustIngredients),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── Zakładka "Ręcznie" ──────────────────────────────────────────────
class _ProductsTab extends StatefulWidget {
  final String? initialBarcode;
  final ApiClient? client;

  const _ProductsTab({this.initialBarcode, this.client});

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  static const _mealTypes = [
    'Śniadanie',
    'Obiad',
    'Kolacja',
    'Przekąska',
    'Deser',
  ];
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FoodLogProvider>().fetchRecentEntries();
    });
  }

  Future<void> _repeat(FoodLogEntry entry) async {
    if (_isAdding) return;
    setState(() => _isAdding = true);
    final provider = context.read<FoodLogProvider>();
    final success = await provider.repeatEntry(entry);
    if (!mounted) return;
    setState(() => _isAdding = false);
    if (success) {
      Navigator.pop(context);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? context.strings.foodEntryRepeatFailed,
          ),
        ),
      );
  }

  Future<void> _pickAndLog(PickedCatalogProduct picked) async {
    if (_isAdding) return;
    var mealType = 'Przekąska';
    final selectedType = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => AlertDialog(
                  title: Text(picked.name),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${picked.amountLabelFor(context.strings)} · '
                        '${picked.kcal.round()} kcal',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: mealType,
                        decoration: InputDecoration(
                          labelText: context.strings.foodEntryMealType,
                        ),
                        items:
                            _mealTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      context.strings.diaryMealTypeLabel(type),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => mealType = value);
                          }
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(context.strings.productsCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, mealType),
                      child: Text(context.strings.foodEntryAddDiary),
                    ),
                  ],
                ),
          ),
    );
    if (selectedType == null || !mounted) return;

    setState(() => _isAdding = true);
    final provider = Provider.of<FoodLogProvider>(context, listen: false);
    final success = await provider.addManualEntry(
      mealType: selectedType,
      foodName: picked.name,
      calories: picked.kcal,
      protein: picked.protein,
      carbs: picked.carbs,
      fat: picked.fat,
      amountValue: _pickedAmountValue(picked),
      amountUnit: _pickedAmountUnit(picked),
      portionSize: picked.portionSize,
      portionUnit: picked.portionUnit,
    );
    if (!mounted) return;
    setState(() => _isAdding = false);
    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              provider.error ?? context.strings.foodEntryProductFailed,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Consumer<FoodLogProvider>(
              builder: (context, provider, _) {
                final entries = provider.recentEntries;
                if (entries.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.history,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            context.strings.foodEntryRepeat,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: entries.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return SizedBox(
                              width: 180,
                              child: OutlinedButton(
                                onPressed:
                                    _isAdding ? null : () => _repeat(entry),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  alignment: Alignment.centerLeft,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${entry.calories.round()} kcal · ${context.strings.diaryMealTypeLabel(entry.mealType)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: PickProductFromCatalogSheet(
                embedded: true,
                client: widget.client,
                initialBarcode: widget.initialBarcode,
                onPicked: (product) => unawaited(_pickAndLog(product)),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: AppTheme.surfaceColor,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) => const SubmitProductSheet(),
                        ),
                    icon: const Icon(Icons.add_box_outlined, size: 18),
                    label: Text(
                      context.strings.foodEntryMissingProduct,
                      maxLines: 2,
                      softWrap: true,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isAdding)
          const ColoredBox(
            color: Color(0x33000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class ManualEntryForm extends StatefulWidget {
  final ProductNameLookupService? nameLookupService;
  const ManualEntryForm({super.key, this.nameLookupService});

  @override
  State<ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<ManualEntryForm> {
  final _formKey = GlobalKey<FormState>();
  String _mealType = 'Przekąska';
  bool _isSubmitting = false;
  final _nameController = TextEditingController();
  final _portionController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String _portionUnit = 'g';

  final List<String> _mealTypes = [
    'Śniadanie',
    'Obiad',
    'Kolacja',
    'Przekąska',
    'Deser',
  ];

  void _applySuggestedProduct(BarcodeLookupResult result) {
    setState(() {
      if (result.name != null) _nameController.text = result.name!;
      _portionController.text = '100';
      _portionUnit = const {'ml', 'l'}.contains(result.unit) ? 'ml' : 'g';
      String number(double? value, int digits) =>
          value != null && value.isFinite && value >= 0
              ? value.toStringAsFixed(digits)
              : '';
      _caloriesController.text = number(result.kcalPer100, 0);
      _proteinController.text = number(result.proteinPer100, 1);
      _carbsController.text = number(result.carbsPer100, 1);
      _fatController.text = number(result.fatPer100, 1);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _portionController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final provider = Provider.of<FoodLogProvider>(context, listen: false);
    // Preserve a physical amount in the existing structured API fields,
    // rather than appending a misleading gram suffix to the product name.
    final portion = _parseNumber(_portionController.text);

    final success = await provider.addManualEntry(
      mealType: _mealType,
      foodName: _nameController.text.trim(),
      calories: _parseNumber(_caloriesController.text)!,
      protein: _parseNumber(_proteinController.text) ?? 0,
      carbs: _parseNumber(_carbsController.text) ?? 0,
      fat: _parseNumber(_fatController.text) ?? 0,
      amountValue: portion,
      amountUnit: portion == null ? null : _portionUnit,
      portionSize: portion == null ? null : 1,
      portionUnit: portion == null ? null : _portionUnit,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              provider.error ?? context.strings.foodEntrySaveFailed,
            ),
          ),
        );
    }
  }

  double? _parseNumber(String value) {
    final number = double.tryParse(value.trim().replaceAll(',', '.'));
    return number != null && number.isFinite ? number : null;
  }

  String? _validateNumber(
    String? value,
    double maximum, {
    bool required = false,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? context.strings.foodEntryRequired : null;
    }
    final number = _parseNumber(value);
    return number == null || number < 0 || number > maximum
        ? context.strings.foodEntryInvalidNumber
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _mealType,
            decoration: InputDecoration(
              labelText: context.strings.foodEntryMealType,
            ),
            items:
                _mealTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(context.strings.diaryMealTypeLabel(type)),
                  );
                }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _mealType = val);
            },
          ),
          const SizedBox(height: 16),
          // NAPRAWA BRAKUJĄCEJ FUNKCJI: przycisk "Dodaj produkt" niżej na
          // tym ekranie od dawna obiecywał "Dodaj produkt raz, a potem
          // wybieraj go z listy" — ale nigdzie w aplikacji nie było
          // żadnej wyszukiwarki, która by to umożliwiła. Ten przycisk
          // domyka tę obietnicę: szuka po tym samym katalogu, do którego
          // trafiają zatwierdzone zgłoszenia.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showModalBottomSheet<PickedCatalogProduct>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: AppTheme.surfaceColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (_) => const PickProductFromCatalogSheet(),
                );
                if (picked == null || !mounted) return;
                setState(() {
                  _nameController.text = picked.name;
                  _portionUnit =
                      picked.portionUnit ?? (picked.unit == 'ml' ? 'ml' : 'g');
                  final physicalAmount =
                      picked.quantity * (picked.portionSize ?? 1);
                  _portionController.text = physicalAmount.toStringAsFixed(
                    physicalAmount == physicalAmount.roundToDouble() ? 0 : 1,
                  );
                  _caloriesController.text = picked.kcal.round().toString();
                  _proteinController.text = picked.protein.toStringAsFixed(1);
                  _fatController.text = picked.fat.toStringAsFixed(1);
                  _carbsController.text = picked.carbs.toStringAsFixed(1);
                });
              },
              icon: const Icon(Icons.search, size: 18),
              label: Text(context.strings.foodEntryChooseCatalogue),
            ),
          ),
          const SizedBox(height: 12),
          ProductNameAutocompleteField(
            controller: _nameController,
            service: widget.nameLookupService,
            maxLength: 255,
            labelText: context.strings.foodEntryProductName,
            hintText: context.strings.foodEntryNameHint,
            onSelected: _applySuggestedProduct,
            validator:
                (val) =>
                    val == null || val.trim().isEmpty
                        ? context.strings.foodEntryNameRequired
                        : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _portionController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.strings.foodEntryPortion,
                    suffixText: _portionUnit,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final number = _parseNumber(value);
                    return number == null || number <= 0 || number > 1000000
                        ? context.strings.foodEntryInvalidPortion
                        : null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _caloriesController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.strings.foodEntryCalories,
                  ),
                  validator:
                      (value) => _validateNumber(value, 10000, required: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _proteinController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.strings.foodEntryProtein,
                  ),
                  validator: (value) => _validateNumber(value, 2000),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _carbsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.strings.foodEntryCarbs,
                  ),
                  validator: (value) => _validateNumber(value, 2000),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _fatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.strings.foodEntryFat,
                  ),
                  validator: (value) => _validateNumber(value, 2000),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
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
                    : Text(context.strings.foodEntrySave),
          ),
        ],
      ),
    );
  }
}
