import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/market_locale.dart';
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
  String? _accountId;
  int _accountGeneration = 0;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MealPlanService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().currentUser;
    final premium = user?.hasPremiumAccess ?? false;
    if (_accountId != user?.id || _hadPremium != premium) {
      _accountId = user?.id;
      _accountGeneration++;
      _loadGeneration++;
      _plans = [];
      _error = null;
      _resumingId = null;
      _loading = true;
      if (premium) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load();
        });
      }
    }
    _hadPremium = premium;
  }

  Future<void> _load() async {
    if (_resumingId != null || !_hadPremium) return;
    final account = _accountGeneration;
    final request = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await _service.getArchivedPlans();
      if (mounted &&
          account == _accountGeneration &&
          request == _loadGeneration) {
        setState(() => _plans = plans);
      }
    } catch (e) {
      if (mounted &&
          account == _accountGeneration &&
          request == _loadGeneration) {
        setState(() => _error = friendlyError(e, strings: context.strings));
      }
    } finally {
      if (mounted &&
          account == _accountGeneration &&
          request == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resume(MealPlan plan) async {
    if (_resumingId != null) return;
    final account = _accountGeneration;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _resumingId = plan.id);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year + 2, today.month, today.day),
      helpText: context.strings.archiveChooseStart,
      cancelText: context.strings.planCancel,
      confirmText: context.strings.archiveChooseDate,
    );
    if (!mounted || account != _accountGeneration) return;
    if (start == null) {
      setState(() => _resumingId = null);
      return;
    }
    final accepted =
        await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text(context.strings.archiveResumeTitle),
                content: Text(
                  context.strings.archiveResumeBody(
                    plan.durationDays,
                    _date(start),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(context.strings.planCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(context.strings.archiveResume),
                  ),
                ],
              ),
        ) ??
        false;
    if (!mounted || account != _accountGeneration) return;
    if (!accepted) {
      setState(() => _resumingId = null);
      return;
    }
    final provider = context.read<MealPlanProvider>();
    final strings = context.strings;
    final resumed = await provider.resumePlan(
      plan.id,
      start,
      errorMessageFor: (error) => friendlyError(error, strings: strings),
    );
    if (!mounted || account != _accountGeneration) return;
    setState(() => _resumingId = null);
    if (resumed != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.archiveResumed)));
      await Navigator.of(context).pushNamed('/plan/view');
    } else {
      setState(
        () =>
            _error =
                provider.errorMessage ?? context.strings.archiveResumeFailed,
      );
    }
  }

  String _date(DateTime date) => DateFormat(
    context.strings.localeName.startsWith('en') ? 'dd/MM/yyyy' : 'dd.MM.yyyy',
  ).format(date);
  String _period(MealPlan plan) {
    final start = DateTime.tryParse(plan.startDate ?? '');
    final end = plan.lastDay;
    if (start == null || end == null) {
      return context.strings.archiveDuration(plan.durationDays);
    }
    return '${_date(start)} – ${_date(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final premium =
        context.watch<AuthProvider>().currentUser?.hasPremiumAccess ?? false;
    final stores = context.watch<StoreProvider>().stores;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.archiveTitle)),
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
                        Text(
                          context.strings.archivePremiumHint,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed:
                              () => Navigator.of(context).pushNamed('/premium'),
                          child: Text(context.strings.archiveSeePremium),
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
                      Text(
                        context.strings.archiveCompleted,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(context.strings.archiveHint),
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
                                  child: Text(context.strings.homeRetry),
                                ),
                            ],
                          ),
                        ),
                      if (_plans.isEmpty && _error == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Text(
                            context.strings.archiveEmpty,
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
                                  context.strings.archivePlanTitle(
                                    plan.durationDays,
                                  ),
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
                                      context.strings.planStoreFallback,
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
                                      child: Text(
                                        context.strings.archivePreview,
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed:
                                          _resumingId == null
                                              ? () => _resume(plan)
                                              : null,
                                      child: Text(
                                        _resumingId == plan.id
                                            ? context.strings.archiveResuming
                                            : context
                                                .strings
                                                .archiveResumeTitle,
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
