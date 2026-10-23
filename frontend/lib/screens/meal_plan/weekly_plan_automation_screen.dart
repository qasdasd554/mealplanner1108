import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/market_locale.dart';

import '../../models/weekly_plan_automation.dart';
import '../../services/meal_plan_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

class WeeklyPlanAutomationScreen extends StatefulWidget {
  final MealPlanService? service;
  const WeeklyPlanAutomationScreen({super.key, this.service});

  @override
  State<WeeklyPlanAutomationScreen> createState() =>
      _WeeklyPlanAutomationScreenState();
}

class _WeeklyPlanAutomationScreenState
    extends State<WeeklyPlanAutomationScreen> {
  late final MealPlanService _service;
  bool _loading = true;
  bool _loadInFlight = false;
  bool _saving = false;
  bool _enabled = false;
  bool _createList = true;
  int _weekday = 6;
  int _hour = 18;
  WeeklyPlanAutomation? _automation;
  String? _error;

  void _applyAutomation(WeeklyPlanAutomation value) {
    _automation = value;
    _enabled = value.enabled;
    _createList = value.createShoppingList;
    _weekday = value.weekday;
    _hour = value.hour;
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MealPlanService();
    _load();
  }

  Future<void> _load() async {
    if (_loadInFlight || _saving) return;
    _loadInFlight = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _service.getWeeklyAutomation();
      if (!mounted) return;
      setState(() {
        _applyAutomation(value);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e, strings: context.strings);
        _loading = false;
      });
    } finally {
      _loadInFlight = false;
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    setState(() => _saving = true);
    try {
      final value = await _service.saveWeeklyAutomation(
        enabled: _enabled,
        weekday: _weekday,
        hour: _hour,
        createShoppingList: _createList,
      );
      if (!mounted) return;
      setState(() => _applyAutomation(value));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _enabled
                  ? context.strings.automationEnabled
                  : context.strings.automationDisabled,
            ),
          ),
        );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, strings: context.strings))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runNow() async {
    if (_saving || _loading) return;
    setState(() => _saving = true);
    try {
      final value = await _service.runWeeklyAutomationNow();
      if (!mounted) return;
      setState(() => _applyAutomation(value));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value.lastError ?? context.strings.automationReady),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, strings: context.strings))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = [
      context.strings.automationMonday,
      context.strings.automationTuesday,
      context.strings.automationWednesday,
      context.strings.automationThursday,
      context.strings.automationFriday,
      context.strings.automationSaturday,
      context.strings.automationSunday,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.automationTitle)),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _load,
                      child: Text(context.strings.automationRetry),
                    ),
                  ],
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    context.strings.automationHeading,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.strings.automationHint,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.strings.automationGenerate),
                            subtitle: Text(
                              context.strings.automationPremiumHint,
                            ),
                            value: _enabled,
                            onChanged:
                                _saving
                                    ? null
                                    : (value) =>
                                        setState(() => _enabled = value),
                          ),
                          const Divider(),
                          DropdownButtonFormField<int>(
                            value: _weekday,
                            isExpanded: true,
                            itemHeight: null,
                            decoration: InputDecoration(
                              labelText: context.strings.automationWeekday,
                              prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                            ),
                            items: [
                              for (var i = 0; i < days.length; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(days[i]),
                                ),
                            ],
                            onChanged:
                                _enabled && !_saving
                                    ? (value) =>
                                        setState(() => _weekday = value!)
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule_outlined),
                            title: Text(context.strings.automationHour),
                            subtitle: Text(
                              '${_hour.toString().padLeft(2, '0')}:00',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            enabled: _enabled && !_saving,
                            onTap:
                                !_enabled || _saving
                                    ? null
                                    : () async {
                                      final selected = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay(
                                          hour: _hour,
                                          minute: 0,
                                        ),
                                      );
                                      if (selected != null && mounted) {
                                        setState(() => _hour = selected.hour);
                                      }
                                    },
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(context.strings.automationCreateList),
                            value: _createList,
                            onChanged:
                                _enabled && !_saving
                                    ? (value) =>
                                        setState(() => _createList = value)
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_automation?.lastSuccessAt != null ||
                      _automation?.lastError != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          _automation?.lastError == null
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color:
                              _automation?.lastError == null
                                  ? AppTheme.primaryColor
                                  : AppTheme.accentColor,
                        ),
                        title: Text(
                          _automation?.lastError ??
                              context.strings.automationLastPlan,
                        ),
                        subtitle:
                            _automation?.lastSuccessAt == null
                                ? null
                                : Text(
                                  DateFormat(
                                    'd MMMM yyyy, HH:mm',
                                    context.strings.localeName,
                                  ).format(
                                    _automation!.lastSuccessAt!.toLocal(),
                                  ),
                                ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save_outlined),
                    label: Text(context.strings.automationSave),
                  ),
                  if (_enabled) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _runNow,
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: Text(context.strings.automationRun),
                    ),
                  ],
                ],
              ),
    );
  }
}
