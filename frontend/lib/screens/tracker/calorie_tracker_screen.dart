import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/food_log_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/food_log.dart';
import 'add_food_entry_screen.dart';

class CalorieTrackerScreen extends StatefulWidget {
  const CalorieTrackerScreen({super.key});

  @override
  State<CalorieTrackerScreen> createState() => _CalorieTrackerScreenState();
}

class _CalorieTrackerScreenState extends State<CalorieTrackerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FoodLogProvider>(context, listen: false).fetchLogsForDate(DateTime.now());
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final provider = Provider.of<FoodLogProvider>(context, listen: false);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceColor,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != provider.currentDate) {
      provider.setDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FoodLogProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Śledzenie kalorii'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : provider.error != null
              ? _buildErrorState(context, provider)
              : RefreshIndicator(
                  onRefresh: () => provider.fetchLogsForDate(provider.currentDate),
                  color: AppTheme.primaryColor,
                  child: ListView(
                    padding: const EdgeInsets.all(24.0),
                    children: [
                      _buildDateHeader(provider.currentDate),
                      const SizedBox(height: 24),
                      _buildProgressSection(provider.summary),
                      const SizedBox(height: 32),
                      _buildMacrosSection(provider.summary),
                      const SizedBox(height: 32),
                      _buildLogsList(context, provider.logs),
                    ],
                  ),
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
    double target = summary?.targetCalories ?? 2000.0;
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosSection(DailySummary? summary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildMacroItem('Białko', summary?.totalProtein ?? 0, AppTheme.accentColor),
        _buildMacroItem('Węgle', summary?.totalCarbs ?? 0, Colors.orange),
        _buildMacroItem('Tłuszcze', summary?.totalFat ?? 0, Colors.redAccent),
      ],
    );
  }

  Widget _buildMacroItem(String label, double amount, Color color) {
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
      onDismissed: (_) {
        Provider.of<FoodLogProvider>(context, listen: false).deleteEntry(item.id);
      },
      child: Container(
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
          ],
        ),
      ),
    );
  }
}
