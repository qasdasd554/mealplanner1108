import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../models/meal_plan.dart';
import '../../services/recipe_service.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';

class AddFoodEntryScreen extends StatefulWidget {
  const AddFoodEntryScreen({super.key});

  @override
  State<AddFoodEntryScreen> createState() => _AddFoodEntryScreenState();
}

class _AddFoodEntryScreenState extends State<AddFoodEntryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Dodaj posiłek'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Z planu'),
            Tab(text: 'Z przepisów'),
            Tab(text: 'Ręcznie'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PlanTab(),
          _RecipesTab(),
          _ManualTab(),
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
  /// Pokazuje krótki dialog wyboru liczby porcji przed zalogowaniem
  /// posiłku z planu — wcześniej "+" logował ZAWSZE dokładnie tyle porcji,
  /// ile było zapisane w planie, bez możliwości powiedzenia "zjadłem
  /// tylko połowę" albo "dołożyłem sobie".
  Future<void> _pickServingsAndLog(BuildContext context, FoodLogProvider provider, MealPlanEntry entry) async {
    double servings = 1.0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(entry.recipe.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ile porcji zjadłeś/-aś?'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: servings > 0.5
                        ? () => setDialogState(() => servings = (servings - 0.5).clamp(0.5, 10))
                        : null,
                  ),
                  Text(servings.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setDialogState(() => servings = (servings + 0.5).clamp(0.5, 10)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dodaj')),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await provider.addFromMealPlanEntry(entry.id, servings: servings);
    if (context.mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Nie udało się dodać posiłku')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
  int? _dayNumberFor(DateTime targetDate, String? startDateStr, int durationDays) {
    if (startDateStr == null) return null;
    final start = DateTime.tryParse(startDateStr);
    if (start == null) return null;
    final startDay = DateTime(start.year, start.month, start.day);
    final targetDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final diff = targetDay.difference(startDay).inDays + 1;
    if (diff < 1 || diff > durationDays) return null;
    return diff;
  }

  @override
  Widget build(BuildContext context) {
    final mealPlanProvider = Provider.of<MealPlanProvider>(context);
    final foodLogProvider = Provider.of<FoodLogProvider>(context);
    final targetDate = foodLogProvider.currentDate;

    if (mealPlanProvider.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    final plan = mealPlanProvider.activePlan;
    if (plan == null) {
      return const _EmptyHint(
        icon: Icons.calendar_today_outlined,
        text: 'Nie masz jeszcze aktywnego planu posiłków.\nUtwórz plan w zakładce "Start", żeby móc\nlogować z niego posiłki jednym dotknięciem.',
      );
    }

    final dayNumber = _dayNumberFor(targetDate, plan.startDate, plan.durationDays);
    if (dayNumber == null) {
      return _EmptyHint(
        icon: Icons.event_busy_outlined,
        text: 'Twój aktywny plan nie obejmuje wybranej daty '
            '(${targetDate.day.toString().padLeft(2, '0')}.${targetDate.month.toString().padLeft(2, '0')}).',
      );
    }

    final entries = plan.entriesForDay(dayNumber);
    if (entries.isEmpty) {
      return const _EmptyHint(
        icon: Icons.no_meals_outlined,
        text: 'Brak zaplanowanych posiłków na wybrany dzień.',
      );
    }

    return ListView.separated(
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
                      entry.mealSlot[0].toUpperCase() + entry.mealSlot.substring(1),
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.recipe.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              foodLogProvider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    )
                  : IconButton(
                      icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 28),
                      tooltip: 'Dodaj do dziennika',
                      onPressed: () => _pickServingsAndLog(context, foodLogProvider, entry),
                    ),
            ],
          ),
        );
      },
    );
  }
}

/// ── Zakładka "Z przepisów" ─────────────────────────────────────────
/// Wcześniej pusty tekst "Wyszukaj z bazy przepisów" — bez pola wyszukiwania
/// i bez żadnej listy. Teraz przeszukuje bazę ~80 przepisów i pozwala dodać
/// wybrany do dziennika z podaniem liczby porcji.
class _RecipesTab extends StatefulWidget {
  const _RecipesTab();

  @override
  State<_RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends State<_RecipesTab> {
  final RecipeService _service = RecipeService();
  final TextEditingController _searchController = TextEditingController();
  List<Recipe> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
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
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await _service.getRecipes(search: query.isEmpty ? null : query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Nie udało się załadować przepisów';
        _loading = false;
      });
    }
  }

  Future<void> _pickAndLog(Recipe recipe) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _LogRecipeSheet(recipe: recipe),
    );
    if (result == null || !mounted) return;

    final foodLogProvider = Provider.of<FoodLogProvider>(context, listen: false);
    final success = await foodLogProvider.addRecipeEntry(
      recipeId: recipe.id,
      mealType: result['mealType'] as String,
      servings: result['servings'] as double,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(foodLogProvider.error ?? 'Nie udało się dodać posiłku')),
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
            decoration: const InputDecoration(
              hintText: 'Szukaj przepisu...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _search,
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _error != null
                  ? _EmptyHint(icon: Icons.error_outline, text: _error!)
                  : _results.isEmpty
                      ? const _EmptyHint(icon: Icons.search_off, text: 'Brak wyników.')
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
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              recipe.name,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              // UWAGA (naprawa): recipe.nutritionTotal to
                                              // wartości dla CAŁEGO przepisu, nie na porcję —
                                              // trzeba podzielić przez recipe.servings, inaczej
                                              // dosłowny podpis "/ porcja" pokazywał wartość
                                              // 2-4x za wysoką. Zabezpieczenie przed servings=0
                                              // (Infinity.round() rzuca wyjątkiem w Dart).
                                              '${(recipe.nutritionTotal.kcal / (recipe.servings > 0 ? recipe.servings : 1)).round()} kcal / porcja',
                                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
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
  final List<String> _mealTypes = ['Śniadanie', 'Obiad', 'Kolacja', 'Przekąska'];
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
            Text(widget.recipe.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Text('Rodzaj posiłku', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _mealTypes.map((t) {
                return ChoiceChip(
                  label: Text(t),
                  selected: _mealType == t,
                  selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  onSelected: (_) => setState(() => _mealType = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Liczba porcji', style: Theme.of(context).textTheme.bodyMedium),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _servings > 0.5
                      ? () => setState(() => _servings = (_servings - 0.5).clamp(0.5, 10))
                      : null,
                ),
                Text(_servings.toStringAsFixed(1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _servings = (_servings + 0.5).clamp(0.5, 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {'mealType': _mealType, 'servings': _servings}),
              child: const Text('Dodaj do dziennika'),
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
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// ── Zakładka "Ręcznie" ──────────────────────────────────────────────
class _ManualTab extends StatelessWidget {
  const _ManualTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24.0),
      child: ManualEntryForm(),
    );
  }
}

class ManualEntryForm extends StatefulWidget {
  const ManualEntryForm({super.key});

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

  final List<String> _mealTypes = ['Śniadanie', 'Obiad', 'Kolacja', 'Przekąska'];

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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final provider = Provider.of<FoodLogProvider>(context, listen: false);
    // Porcja (g/ml) nie ma osobnej kolumny w backendzie — dopisujemy ją do
    // nazwy, żeby informacja nie ginęła (np. "Owsianka (300g)").
    final portionText = _portionController.text.trim();
    final name = portionText.isEmpty
        ? _nameController.text.trim()
        : '${_nameController.text.trim()} (${portionText}g)';

    final success = await provider.addManualEntry(
      mealType: _mealType,
      foodName: name,
      calories: double.tryParse(_caloriesController.text) ?? 0,
      protein: double.tryParse(_proteinController.text) ?? 0,
      carbs: double.tryParse(_carbsController.text) ?? 0,
      fat: double.tryParse(_fatController.text) ?? 0,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Nie udało się dodać wpisu')),
      );
    }
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
            decoration: const InputDecoration(labelText: 'Rodzaj posiłku'),
            items: _mealTypes.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _mealType = val);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nazwa produktu / dania'),
            validator: (val) => val == null || val.isEmpty ? 'Podaj nazwę' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _portionController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Porcja (g/ml, opcjonalnie)'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kalorie (kcal)'),
                  validator: (val) => val == null || val.isEmpty ? 'Wymagane' : null,
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
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Białko (g)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _carbsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Węgle (g)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _fatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tłuszcz (g)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Zapisz do dziennika'),
          ),
        ],
      ),
    );
  }
}
