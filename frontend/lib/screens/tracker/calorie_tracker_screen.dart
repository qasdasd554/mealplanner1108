import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/food_log_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decorative_circles.dart';
import '../../models/food_log.dart';
import '../../providers/wellness_provider.dart';
import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../widgets/edit_ingredients_sheet.dart';
import '../../utils/error_utils.dart';

class CalorieTrackerScreen extends StatefulWidget {
  const CalorieTrackerScreen({super.key});

  @override
  State<CalorieTrackerScreen> createState() => _CalorieTrackerScreenState();
}

class _CalorieTrackerScreenState extends State<CalorieTrackerScreen> {
  // Id pozycji aktualnie "odsłoniętej" na czerwono po dotknięciu — tylko
  // jedna naraz. Dotknięcie tej samej pozycji ponownie (albo usunięcie)
  // ją chowa z powrotem.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FoodLogProvider>(context, listen: false).fetchLogsForDate(DateTime.now());
      // Nawodnienie i aktywności ładujemy dla tego samego dnia — osobny
      // provider, bo to dane uzupełniające (patrz WellnessProvider).
      Provider.of<WellnessProvider>(context, listen: false).loadForDate(DateTime.now());
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final provider = Provider.of<FoodLogProvider>(context, listen: false);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      // UWAGA (naprawa): wcześniej to okno ZAWSZE wymuszało ciemny motyw
      // (ThemeData.dark()), niezależnie od tego, jaki motyw był wybrany
      // w aplikacji. Po wprowadzeniu jasnego motywu jako domyślnego dawało
      // to niespójny, myjący kontrast wygląd, przez który kalendarz mógł
      // sprawiać wrażenie zepsutego/nieczytelnego. Teraz respektuje
      // aktualnie wybrany motyw (Theme.of(context) — jasny albo ciemny).
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != provider.currentDate) {
      provider.setDate(picked);
      // Nawodnienie i aktywności muszą podążać za wybraną datą —
      // inaczej pokazywałyby dane innego dnia niż reszta ekranu.
      if (mounted) {
        Provider.of<WellnessProvider>(context, listen: false).loadForDate(picked);
      }
    }
  }

  void _goToPreviousDay() {
    final provider = Provider.of<FoodLogProvider>(context, listen: false);
    _changeDate(provider, provider.currentDate.subtract(const Duration(days: 1)));
  }

  void _goToNextDay() {
    final provider = Provider.of<FoodLogProvider>(context, listen: false);
    _changeDate(provider, provider.currentDate.add(const Duration(days: 1)));
  }

  /// Zmienia dzień w OBU providerach naraz. Osobna metoda, bo data jest
  /// przełączana z czterech miejsc (strzałki, kalendarz, "dziś") i przy
  /// każdym z nich łatwo byłoby zapomnieć o nawodnieniu — wtedy ekran
  /// pokazywałby posiłki z jednego dnia, a wodę z innego.
  void _changeDate(FoodLogProvider provider, DateTime date) {
    provider.setDate(date);
    Provider.of<WellnessProvider>(context, listen: false).loadForDate(date);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FoodLogProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Śledzenie kalorii'),
        actions: [
          // Kalkulator zapotrzebowania (waga, wzrost, BMI, cel kaloryczny)
          // PRZENIESIONY do zakładki Profil — jako ikona w pasku był
          // praktycznie nie do znalezienia, a to ustawienie konta,
          // nie codzienna czynność. Patrz profile_screen.dart.
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          const DecorativeCircles(),
          provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : provider.error != null
              ? _buildErrorState(context, provider)
              : RefreshIndicator(
                  onRefresh: () async {
                    await provider.fetchLogsForDate(provider.currentDate);
                    await Provider.of<WellnessProvider>(context, listen: false)
                        .loadForDate(provider.currentDate);
                  },
                  color: AppTheme.primaryColor,
                  child: ListView(
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      _buildDateNavigation(provider.currentDate),
                      const SizedBox(height: 24),
                      _buildProgressSection(provider.summary),
                      const SizedBox(height: 16),
                      // Przycisk aktywności TUŻ pod licznikiem — spalone
                      // kalorie powiększają dzienny limit, więc naturalne
                      // miejsce jest przy liczbie, na którą wpływają.
                      _buildActivitySection(context),
                      const SizedBox(height: 24),
                      _buildWaterSection(context),
                      const SizedBox(height: 32),
                      _buildMacrosSection(provider.summary),
                      const SizedBox(height: 32),
                      _buildLogsList(context, provider.logs),
                    ],
                  ),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/tracker/add');
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, FoodLogProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              provider.error ?? 'Nie udało się załadować dziennika.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => provider.fetchLogsForDate(provider.currentDate),
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }

  /// Pasek nawigacji dat — strzałki wstecz/dalej + dotknięcie daty otwiera
  /// kalendarz. Wcześniej jedynym sposobem zmiany daty była mała ikonka
  /// kalendarza w AppBarze, co nie było oczywiste — stąd wrażenie, że
  /// "nie da się zmienić daty, pokazuje tylko dziś".
  Widget _buildDateNavigation(DateTime date) {
    final isToday = _isToday(date);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: AppTheme.primaryColor),
          tooltip: 'Poprzedni dzień',
          onPressed: _goToPreviousDay,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(context),
            child: Column(
              children: [
                _buildDateHeader(date),
                if (!isToday) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      Provider.of<FoodLogProvider>(context, listen: false)
                          .setDate(DateTime.now());
                      Provider.of<WellnessProvider>(context, listen: false)
                          .loadForDate(DateTime.now());
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Wróć do dziś', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
          tooltip: 'Następny dzień',
          // Celowo NIE blokujemy nawigacji w przyszłość — użytkownik może
          // chcieć zaplanować/zapisać wpis z wyprzedzeniem.
          onPressed: _goToNextDay,
        ),
      ],
    );
  }

  Widget _buildDateHeader(DateTime date) {
    // Zabezpieczenie: jeśli z jakiegoś powodu dane locale 'pl_PL' nie są
    // zainicjalizowane (mimo initializeDateFormatting w main.dart),
    // DateFormat rzuciłby wyjątek i wywalił CAŁY ekran na biało — tak jak
    // się to wcześniej działo. Fallback gwarantuje, że w najgorszym razie
    // data wygląda gorzej (format domyślny), ale ekran zawsze się wyrenderuje.
    String formattedDate;
    try {
      formattedDate = DateFormat('dd MMMM yyyy', 'pl_PL').format(date);
    } catch (_) {
      formattedDate = DateFormat('dd.MM.yyyy').format(date);
    }
    if (date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day) {
      formattedDate = 'Dzisiaj, $formattedDate';
    }

    return Text(
      formattedDate,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildProgressSection(DailySummary? summary) {
    double consumed = summary?.totalCalories ?? 0.0;
    final baseTarget = summary?.targetCalories ?? 2000.0;

    // Kalorie spalone aktywnością POWIĘKSZAJĄ dzienny limit — to, co
    // użytkownik wypracował bieganiem czy rowerem, może zjeść dodatkowo.
    // Dlatego dodajemy je do celu, zamiast odejmować od spożytych: dzięki
    // temu widać osobno "ile zjadłem" i "ile wypracowałem", a nie jedną
    // zafałszowaną liczbę.
    final burned = Provider.of<WellnessProvider>(context).kcalBurned.toDouble();
    final double target = baseTarget + burned;

    double remaining = target - consumed;
    if (remaining < 0) remaining = 0;
    double progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              backgroundColor: AppTheme.surfaceColor,
              color: progress > 1.0 ? Colors.red : AppTheme.primaryColor,
            ),
          ),
          Column(
            children: [
              Text(
                '${remaining.toInt()}',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'kcal pozostało',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (burned > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '+${burned.toInt()} z aktywności',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Aktywność fizyczna — lista wpisów z dnia i przycisk dodawania.
  Widget _buildActivitySection(BuildContext context) {
    final wellness = Provider.of<WellnessProvider>(context);
    final activities = wellness.data.activities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...activities.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.local_fire_department_outlined,
                    size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.durationMin != null && a.durationMin! > 0
                        ? '${a.name} · ${a.durationMin} min'
                        : a.name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '+${a.kcalBurned} kcal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _runWellness(wellness, () => wellness.deleteActivity(a.id)),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showAddActivityDialog(context, wellness),
            icon: const Icon(Icons.directions_run, size: 18),
            label: const Text('Dodaj aktywność'),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddActivityDialog(
      BuildContext context, WellnessProvider wellness) async {
    final nameController = TextEditingController();
    final kcalController = TextEditingController();
    final minutesController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dodaj aktywność'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Co robiłeś/aś?',
                  hintText: 'np. bieganie, rower, siłownia',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: kcalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Spalone kalorie',
                  suffixText: 'kcal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Czas (opcjonalnie)',
                  suffixText: 'min',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final name = nameController.text.trim();
    final kcal = int.tryParse(kcalController.text.trim());
    if (name.isEmpty || kcal == null || kcal <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
            duration: Duration(seconds: 3),content: Text('Podaj nazwę i liczbę spalonych kalorii.')),
          );
      }
      return;
    }

    await _runWellness(
      wellness,
      () => wellness.addActivity(
        name: name,
        kcalBurned: kcal,
        durationMin: int.tryParse(minutesController.text.trim()),
      ),
    );
  }

  /// Nawodnienie — pasek postępu i szybkie przyciski dolewania.
  /// Wykonuje akcję nawodnienia/aktywności i POKAZUJE ewentualny błąd.
  ///
  /// Bez tego provider zapisywał błąd, ale nic go nie wyświetlało —
  /// dotknięcie przycisku wyglądało, jakby aplikacja je zignorowała.
  Future<void> _runWellness(
      WellnessProvider wellness, Future<dynamic> Function() action) async {
    await action();
    if (!mounted) return;
    final error = wellness.consumeError();
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),content: Text(error), backgroundColor: AppTheme.errorColor),
        );
    }
  }

  /// Nawodnienie — układ SPÓJNY z kafelkami na ekranie startowym
  /// i w profilu: ikona w kolorowym kwadracie po lewej, treść w środku,
  /// wskaźnik po prawej. Wcześniej ten kafelek miał własny układ
  /// (nagłówek, pasek pod spodem, przyciski w trzecim rzędzie), przez co
  /// odstawał wyglądem od reszty aplikacji i zajmował więcej miejsca,
  /// niż wymaga jedna liczba.
  /// Otwiera edycję składników dla ISTNIEJĄCEGO wpisu w dzienniku.
  ///
  /// Zmiana dotyczy WYŁĄCZNIE tego wpisu, tego dnia i tego użytkownika —
  /// przepis pozostaje nietknięty, a inne wpisy z tego samego przepisu
  /// zachowują swoje wartości.
  Future<void> _editEntryIngredients(dynamic item) async {
    final messenger = ScaffoldMessenger.of(context);
    Recipe recipe;
    try {
      recipe = await RecipeService().getRecipe(item.recipeId as String);
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(friendlyError(e)),
        ));
      return;
    }
    if (!mounted) return;

    if (recipe.ingredients.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          duration: Duration(seconds: 3),
          content: Text('Ten przepis nie ma listy składników do edycji.'),
        ));
      return;
    }

    final edited = await showModalBottomSheet<EditedNutrition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditIngredientsSheet(
        recipe: recipe,
        // Wpis mógł zostać dodany z inną liczbą porcji niż cały przepis —
        // przeliczamy proporcjonalnie, żeby liczby odpowiadały temu,
        // co użytkownik faktycznie zapisał.
        servingsFraction: (item.servings as double) /
            (recipe.servings > 0 ? recipe.servings : 1),
      ),
    );
    if (edited == null || !mounted || !edited.wasEdited) return;

    final ok = await Provider.of<FoodLogProvider>(context, listen: false)
        .updateEntryNutrition(
      item.id as String,
      calories: edited.kcal,
      protein: edited.protein,
      fat: edited.fat,
      carbs: edited.carbs,
    );
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(ok
            ? 'Zaktualizowano kaloryczność wpisu'
            : 'Nie udało się zapisać zmian'),
      ));
  }

  Widget _buildWaterSection(BuildContext context) {
    final wellness = Provider.of<WellnessProvider>(context);
    const waterBlue = Color(0xFF3B9AE1);

    if (!wellness.hasLoaded || wellness.isLoading) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: waterBlue.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Wczytywanie nawodnienia…')),
          ],
        ),
      );
    }

    if (wellness.errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: waterBlue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: waterBlue),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Nie udało się wczytać nawodnienia.'),
            ),
            IconButton(
              tooltip: 'Spróbuj ponownie',
              onPressed: () => wellness.loadForDate(
                Provider.of<FoodLogProvider>(context, listen: false).currentDate,
              ),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }

    final ml = wellness.data.waterMl;
    final goal = wellness.data.waterGoalMl;
    final progress = goal > 0 ? (ml / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: waterBlue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: waterBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.water_drop, color: waterBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nawodnienie',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                      '$ml z $goal ml',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Kółko postępu zamiast paska pod spodem — mieści się
              // w wierszu, więc kafelek jest niższy, a procent czytelny
              // od razu.
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3.5,
                      backgroundColor: waterBlue.withOpacity(0.15),
                      color: waterBlue,
                    ),
                    Text(
                      '${(progress * 100).round()}',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold, color: waterBlue),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _waterButton(wellness, 250, 'Szklanka'),
              const SizedBox(width: 6),
              _waterButton(wellness, 500, 'Butelka'),
              const SizedBox(width: 6),
              // Wpisanie dowolnej ilości — potrzebne, gdy ktoś wypił
              // np. 300 ml albo chce wpisać całodzienną sumę naraz.
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showCustomWaterDialog(context, wellness),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Inna ilość', style: TextStyle(fontSize: 12)),
                ),
              ),
              if (ml > 0)
                IconButton(
                  icon: Icon(Icons.undo, size: 17, color: AppTheme.textSecondary),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Cofnij szklankę',
                  onPressed: () =>
                      _runWellness(wellness, () => wellness.addWater(-250)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Wpisanie dowolnej liczby mililitrów.
  Future<void> _showCustomWaterDialog(
      BuildContext context, WellnessProvider wellness) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ile wypiłeś/aś?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Ilość',
            suffixText: 'ml',
            hintText: 'np. 300',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            duration: Duration(seconds: 3),content: Text('Podaj liczbę mililitrów.')));
      }
      return;
    }
    // Backend przyjmuje maksymalnie 2000 ml na jedno żądanie, więc
    // większą ilość dzielimy na kilka — inaczej wpis zostałby odrzucony
    // jako niepoprawny, bez zrozumiałego dla użytkownika powodu.
    var left = value;
    while (left > 0) {
      final chunk = left > 2000 ? 2000 : left;
      await _runWellness(wellness, () => wellness.addWater(chunk));
      left -= chunk;
    }
  }

  /// Przycisk szybkiego dolania. Owinięty w Expanded, żeby trzy przyciski
  /// dzieliły szerokość równo — bez tego długie etykiety rozpychały wiersz
  /// i wychodziły poza ekran na wąskich telefonach.
  Widget _waterButton(WellnessProvider wellness, int ml, String label) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _runWellness(wellness, () => wellness.addWater(ml)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 6),
          visualDensity: VisualDensity.compact,
        ),
        child: Text('+$label',
            style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildMacrosSection(DailySummary? summary) {
    // UWAGA (naprawa): wcześniej pokazywało TYLKO to, ile faktycznie
    // zjedzono — bez żadnego odniesienia, ile jest OPTYMALNE dla
    // dziennego celu kcal. Dodane przewidywane, optymalne wartości (ten
    // sam podział 25% białko / 30% tłuszcz / 45% węglowodany co w
    // kalkulatorze kalorii i na ekranie głównym — spójne w całej
    // aplikacji), żeby można było od razu porównać "zjadłem X, cel to Y".
    final targetKcal = summary?.targetCalories ?? 2000.0;
    final targetProtein = targetKcal * 0.25 / 4;
    final targetFat = targetKcal * 0.30 / 9;
    final targetCarbs = targetKcal * 0.45 / 4;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMacroItem('Białko', summary?.totalProtein ?? 0, AppTheme.accentColor, target: targetProtein),
            _buildMacroItem('Węgle', summary?.totalCarbs ?? 0, Colors.orange, target: targetCarbs),
            _buildMacroItem('Tłuszcze', summary?.totalFat ?? 0, Colors.redAccent, target: targetFat),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Optymalny podział dla Twojego celu kcal',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildMacroItem(String label, double amount, Color color, {required double target}) {
    return Column(
      children: [
        Text(
          '${amount.toInt()}g',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          '/ ${target.round()}g',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLogsList(BuildContext context, List<FoodLogEntry> logs) {
    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Brak zjedzonych posiłków w tym dniu.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final Map<String, List<FoodLogEntry>> groupedLogs = {};
    for (var log in logs) {
      groupedLogs.putIfAbsent(log.mealType, () => []).add(log);
    }

    final orderedMealTypes = ['Śniadanie', 'Obiad', 'Kolacja', 'Przekąska'];
    final existingTypes = groupedLogs.keys.toList()
      ..sort((a, b) {
        int indexA = orderedMealTypes.indexOf(a);
        int indexB = orderedMealTypes.indexOf(b);
        if (indexA == -1) indexA = 99;
        if (indexB == -1) indexB = 99;
        return indexA.compareTo(indexB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: existingTypes.map((type) {
        final items = groupedLogs[type]!;
        double totalCal = items.fold(0, (sum, item) => sum + item.calories);

        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${totalCal.toInt()} kcal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...items.map((item) => _buildLogItem(context, item)).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<bool> _confirmDeleteEntry(FoodLogEntry item) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Usunąć posiłek?'),
            content: Text('„${item.displayName}” zostanie usunięty ze śledzenia.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Usuń'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildLogItem(BuildContext context, FoodLogEntry item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDeleteEntry(item),
      onDismissed: (_) {
        Provider.of<FoodLogProvider>(context, listen: false).deleteEntry(item.id);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (item.recipeId != null) {
            _editEntryIngredients(item);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
                  children: [
                    Icon(
                      item.recipeId != null ? Icons.menu_book_outlined : Icons.restaurant_menu,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.servings == 1
                                ? '1 porcja'
                                : '${item.servings.toStringAsFixed(item.servings.truncateToDouble() == item.servings ? 0 : 1)} porcji',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${item.calories.toInt()} kcal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('B:${item.protein.toInt()}', style: const TextStyle(fontSize: 12, color: AppTheme.accentColor)),
                            const SizedBox(width: 4),
                            Text('W:${item.carbs.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                            const SizedBox(width: 4),
                            Text('T:${item.fat.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Usuń ze śledzenia',
                      icon: Icon(Icons.delete_outline, color: AppTheme.errorColor),
                      onPressed: () async {
                        if (await _confirmDeleteEntry(item) && mounted) {
                          await Provider.of<FoodLogProvider>(context, listen: false)
                              .deleteEntry(item.id);
                        }
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
