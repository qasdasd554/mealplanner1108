import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/weight_log.dart';
import '../../models/wellness_statistics.dart';
import '../../services/wellness_statistics_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final WellnessStatisticsService _service = WellnessStatisticsService();
  WellnessStatistics? _statistics;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getStatistics();
      if (mounted) setState(() => _statistics = result);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statystyki')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Spróbuj ponownie')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _content(_statistics!),
                ),
    );
  }

  Widget _content(WellnessStatistics statistics) {
    final chartDays = statistics.days.length > 14
        ? statistics.days.sublist(statistics.days.length - 14)
        : statistics.days;
    final chartLabels = chartDays.map((day) => _shortDate(day.date)).toList();
    final hasCalories = chartDays.any((day) => day.calories > 0);
    final hasMacros = chartDays.any(
      (day) => day.protein > 0 || day.fat > 0 || day.carbs > 0,
    );
    final hasWater = chartDays.any((day) => day.waterMl > 0);
    final recentDays = statistics.days
        .where((day) => day.calories > 0 || day.waterMl > 0)
        .toList()
        .reversed
        .take(7)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(
          title: 'Zmiana wagi',
          icon: Icons.monitor_weight_outlined,
          child: statistics.weights.isEmpty
              ? const _EmptyText('Dodaj co najmniej jeden pomiar w profilu.')
              : _WeightChart(weights: statistics.weights),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _summaryTile('Średnio kcal', '${statistics.averageCalories.toStringAsFixed(0)} kcal', Icons.local_fire_department_outlined),
            _summaryTile('Nawodnienie', '${statistics.averageWaterMl} ml', Icons.water_drop_outlined),
            _summaryTile('Ulubiony posiłek', statistics.favoriteMeal ?? 'Brak danych', Icons.favorite_outline),
          ],
        ),
        const SizedBox(height: 14),
        _section(
          title: 'Kalorie dziennie',
          icon: Icons.local_fire_department_outlined,
          child: !hasCalories
              ? const _EmptyText(
                  'Dodaj posiłki w Śledzeniu, aby zobaczyć wykres.',
                )
              : _TrendChart(
                  labels: chartLabels,
                  unit: 'kcal',
                  series: [
                    _ChartSeries(
                      label: 'Kalorie',
                      color: AppTheme.accentColor,
                      values:
                          chartDays.map((day) => day.calories).toList(),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _section(
          title: 'Makroskładniki dziennie',
          icon: Icons.pie_chart_outline,
          child: !hasMacros
              ? const _EmptyText(
                  'Makroskładniki pojawią się po dodaniu posiłków.',
                )
              : _TrendChart(
                  labels: chartLabels,
                  unit: 'g',
                  series: [
                    _ChartSeries(
                      label: 'Białko',
                      color: AppTheme.primaryColor,
                      values: chartDays.map((day) => day.protein).toList(),
                    ),
                    _ChartSeries(
                      label: 'Tłuszcze',
                      color: AppTheme.accentColor,
                      values: chartDays.map((day) => day.fat).toList(),
                    ),
                    _ChartSeries(
                      label: 'Węglowodany',
                      color: AppTheme.secondaryColor,
                      values: chartDays.map((day) => day.carbs).toList(),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _section(
          title: 'Nawodnienie dziennie',
          icon: Icons.water_drop_outlined,
          child: !hasWater
              ? const _EmptyText(
                  'Zapisuj wodę w Śledzeniu, aby zobaczyć wykres.',
                )
              : _TrendChart(
                  labels: chartLabels,
                  unit: 'ml',
                  series: [
                    _ChartSeries(
                      label: 'Woda',
                      color: Colors.blue,
                      values: chartDays
                          .map((day) => day.waterMl.toDouble())
                          .toList(),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _section(
          title: 'Ostatnie zapisane dni',
          icon: Icons.calendar_month_outlined,
          child: recentDays.isEmpty
              ? const _EmptyText('Zapisane posiłki i nawodnienie pojawią się tutaj.')
              : Column(
                  children: recentDays
                      .map((day) => _dailyRow(day))
                      .toList(),
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _section({required String title, required IconData icon, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.textSecondary.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  Widget _summaryTile(String label, String value, IconData icon) => SizedBox(
        width: 166,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ]),
        ),
      );

  Widget _dailyRow(DailyWellnessStatistics day) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_date(day.date), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(
            '${day.calories.toStringAsFixed(0)} kcal  •  B ${day.protein.toStringAsFixed(1)} g  •  '
            'T ${day.fat.toStringAsFixed(1)} g  •  W ${day.carbs.toStringAsFixed(1)} g',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          Text('Woda: ${day.waterMl} ml',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      );

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  String _shortDate(DateTime value) => '${value.day}.${value.month}';
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(color: AppTheme.textSecondary),
        textAlign: TextAlign.center,
      );
}

class _ChartSeries {
  final String label;
  final Color color;
  final List<double> values;

  const _ChartSeries({
    required this.label,
    required this.color,
    required this.values,
  });
}

class _TrendChart extends StatelessWidget {
  final List<_ChartSeries> series;
  final List<String> labels;
  final String unit;

  const _TrendChart({
    required this.series,
    required this.labels,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    var maximum = 0.0;
    for (final item in series) {
      for (final value in item.values) {
        if (value > maximum) maximum = value;
      }
    }
    final decimals = unit == 'g' ? 1 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Maksimum: ${maximum.toStringAsFixed(decimals)} $unit',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 165,
          child: CustomPaint(
            painter: _TrendChartPainter(
              series: series,
              gridColor: Theme.of(context).dividerColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        if (labels.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: Text(
                  labels.first,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  labels.last,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: series
              .map(
                (item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(item.label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<_ChartSeries> series;
  final Color gridColor;

  const _TrendChartPainter({
    required this.series,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var maximum = 0.0;
    for (final item in series) {
      for (final value in item.values) {
        if (value > maximum) maximum = value;
      }
    }
    if (maximum <= 0) maximum = 1;

    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.25)
      ..strokeWidth = 1;
    for (var line = 0; line <= 3; line++) {
      final y = size.height * line / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final item in series) {
      if (item.values.isEmpty) continue;
      final path = Path();
      final linePaint = Paint()
        ..color = item.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final pointPaint = Paint()..color = item.color;

      for (var index = 0; index < item.values.length; index++) {
        final x = item.values.length == 1
            ? size.width / 2
            : size.width * index / (item.values.length - 1);
        final y = size.height -
            (item.values[index] / maximum * (size.height - 12)) -
            6;
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 3, pointPaint);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.gridColor != gridColor;
}

class _WeightChart extends StatelessWidget {
  final List<WeightLogEntry> weights;
  const _WeightChart({required this.weights});

  @override
  Widget build(BuildContext context) {
    final first = weights.first;
    final last = weights.last;
    final difference = last.weightKg - first.weightKg;
    return Column(children: [
      SizedBox(
        height: 170,
        child: CustomPaint(
          painter: _WeightChartPainter(weights, Theme.of(context).dividerColor),
          child: const SizedBox.expand(),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text(_shortDate(first.date), style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
        Text(
          '${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(1)} kg',
          style: TextStyle(fontWeight: FontWeight.bold, color: difference <= 0 ? AppTheme.primaryColor : AppTheme.accentColor),
        ),
        Expanded(child: Text(_shortDate(last.date), textAlign: TextAlign.end,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
      ]),
    ]);
  }

  static String _shortDate(DateTime value) => '${value.day}.${value.month}';
}

class _WeightChartPainter extends CustomPainter {
  final List<WeightLogEntry> values;
  final Color gridColor;
  const _WeightChartPainter(this.values, this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    final weights = values.map((entry) => entry.weightKg).toList();
    final minimum = weights.reduce(math.min);
    final maximum = weights.reduce(math.max);
    final spread = math.max(maximum - minimum, 1.0);
    final gridPaint = Paint()..color = gridColor.withOpacity(0.25)..strokeWidth = 1;
    for (var line = 0; line <= 3; line++) {
      final y = size.height * line / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final linePaint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = AppTheme.primaryColor;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1 ? size.width / 2 : size.width * index / (values.length - 1);
      final y = size.height - ((weights[index] - minimum) / spread * (size.height - 12)) - 6;
      if (index == 0) path.moveTo(x, y); else path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.gridColor != gridColor;
}
