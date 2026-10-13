import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/meal_plan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/store_provider.dart';
import '../../services/meal_plan_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../widgets/premium_badge.dart';

class PlanArchiveScreen extends StatefulWidget {
  final MealPlanService? service;
  const PlanArchiveScreen({super.key, this.service});

  @override
  State<PlanArchiveScreen> createState() => _PlanArchiveScreenState();
}

class _PlanArchiveScreenState extends State<PlanArchiveScreen> {
  late final MealPlanService _service;
  bool _loading = true;
  String? _error;
  String? _resumingId;
  List<MealPlan> _plans = [];
  bool _hadPremium = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MealPlanService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final premium =
        context.watch<AuthProvider>().currentUser?.hasPremiumAccess ?? false;
    if (premium && !_hadPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    _hadPremium = premium;
  }

  Future<void> _load() async {
    if (_resumingId != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await _service.getArchivedPlans();
      if (mounted) setState(() => _plans = plans);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resume(MealPlan plan) async {
    if (_resumingId != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _resumingId = plan.id);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year + 2, today.month, today.day),
      helpText: 'Od kiedy wznowić plan?',
      cancelText: 'Anuluj',
      confirmText: 'Wybierz datę',
    );
    if (!mounted) return;
    if (start == null) {
      setState(() => _resumingId = null);
      return;
    }
    final accepted =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Wznów plan'),
                content: Text(
                  'Te same posiłki na ${plan.durationDays} dni od ${_date(start)}. '
                  'Plan pozostanie też w archiwum. Utworzymy nową listę zakupów. '
                  'Bez generowania AI i bez wydawania punktów.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Anuluj'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Wznów'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!mounted) return;
    if (!accepted) {
      setState(() => _resumingId = null);
      return;
    }
    final provider = context.read<MealPlanProvider>();
    final resumed = await provider.resumePlan(plan.id, start);
    if (!mounted) return;
    setState(() => _resumingId = null);
    if (resumed != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan został wznowiony.')));
      await Navigator.of(context).pushNamed('/plan/view');
    } else {
      setState(
        () =>
            _error =
                provider.errorMessage ??
                'Nie udało się wznowić planu. Spróbuj ponownie.',
      );
    }
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  String _period(MealPlan plan) {
    final start = DateTime.tryParse(plan.startDate ?? '');
    final end = plan.lastDay;
    if (start == null || end == null) return '${plan.durationDays} dni';
    return '${_date(start)} – ${_date(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final premium =
        context.watch<AuthProvider>().currentUser?.hasPremiumAccess ?? false;
    final stores = context.watch<StoreProvider>().stores;
    return Scaffold(
      appBar: AppBar(title: const Text('Archiwum planów')),
      body: SafeArea(
        child:
            !premium
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PremiumBadge(),
                        const SizedBox(height: 16),
                        const Text(
                          'Z Premium zakończone plany pozostają w archiwum. Możesz je przeglądać i wznowić bez generowania przez AI.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed:
                              () => Navigator.of(context).pushNamed('/premium'),
                          child: const Text('Zobacz Premium'),
                        ),
                      ],
                    ),
                  ),
                )
                : _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const Text(
                        'Zakończone plany',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Wznów ten sam zestaw posiłków od nowej daty. Nie używamy AI ani punktów Premium.',
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              ),
                              if (_plans.isEmpty)
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('Spróbuj ponownie'),
                                ),
                            ],
                          ),
                        ),
                      if (_plans.isEmpty && _error == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: Text(
                            'Nie masz jeszcze zakończonych planów. Po ostatnim dniu aktywny plan trafi tutaj.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final plan in _plans)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Plan na ${plan.durationDays} dni',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(_period(plan)),
                                const SizedBox(height: 4),
                                Text(
                                  stores
                                          .where((s) => s.id == plan.storeId)
                                          .firstOrNull
                                          ?.name ??
                                      'Sklep',
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed:
                                          _resumingId == null
                                              ? () async {
                                                await Navigator.of(
                                                  context,
                                                ).pushNamed(
                                                  '/plan/view',
                                                  arguments: plan,
                                                );
                                                if (mounted) _load();
                                              }
                                              : null,
                                      child: const Text('Podgląd'),
                                    ),
                                    FilledButton(
                                      onPressed:
                                          _resumingId == null
                                              ? () => _resume(plan)
                                              : null,
                                      child: Text(
                                        _resumingId == plan.id
                                            ? 'Wznawianie…'
                                            : 'Wznów plan',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }
}
