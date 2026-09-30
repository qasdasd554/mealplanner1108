import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/weekly_plan_automation.dart';
import '../../services/meal_plan_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

class WeeklyPlanAutomationScreen extends StatefulWidget {
  const WeeklyPlanAutomationScreen({super.key});

  @override
  State<WeeklyPlanAutomationScreen> createState() =>
      _WeeklyPlanAutomationScreenState();
}

class _WeeklyPlanAutomationScreenState
    extends State<WeeklyPlanAutomationScreen> {
  static const _days = [
    'Poniedziałek',
    'Wtorek',
    'Środa',
    'Czwartek',
    'Piątek',
    'Sobota',
    'Niedziela',
  ];

  final _service = MealPlanService();
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  bool _createList = true;
  int _weekday = 6;
  int _hour = 18;
  WeeklyPlanAutomation? _automation;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _service.getWeeklyAutomation();
      if (!mounted) return;
      setState(() {
        _automation = value;
        _enabled = value.enabled;
        _createList = value.createShoppingList;
        _weekday = value.weekday;
        _hour = value.hour;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final value = await _service.saveWeeklyAutomation(
        enabled: _enabled,
        weekday: _weekday,
        hour: _hour,
        createShoppingList: _createList,
      );
      if (!mounted) return;
      setState(() => _automation = value);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _enabled
                  ? 'Automatyczny tydzień jest włączony.'
                  : 'Automatyczny tydzień jest wyłączony.',
            ),
          ),
        );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runNow() async {
    setState(() => _saving = true);
    try {
      final value = await _service.runWeeklyAutomationNow();
      if (!mounted) return;
      setState(() => _automation = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value.lastError ?? 'Plan jest gotowy. Sprawdź go w zakładce Start.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Automatyczny tydzień')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Ponów')),
                  ],
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Plan gotowy, zanim zacznie się tydzień',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Co tydzień przygotujemy 7-dniowy plan na podstawie Twojego celu, preferencji i ulubionego sklepu.',
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
                            title: const Text('Generuj automatycznie'),
                            subtitle: const Text(
                              'Tylko podczas aktywnego Premium',
                            ),
                            value: _enabled,
                            onChanged:
                                (value) => setState(() => _enabled = value),
                          ),
                          const Divider(),
                          DropdownButtonFormField<int>(
                            value: _weekday,
                            decoration: const InputDecoration(
                              labelText: 'Dzień tygodnia',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            items: [
                              for (var i = 0; i < _days.length; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(_days[i]),
                                ),
                            ],
                            onChanged:
                                _enabled
                                    ? (value) =>
                                        setState(() => _weekday = value!)
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule_outlined),
                            title: const Text('Godzina'),
                            subtitle: Text(
                              '${_hour.toString().padLeft(2, '0')}:00',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            enabled: _enabled,
                            onTap: () async {
                              final selected = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: _hour, minute: 0),
                              );
                              if (selected != null && mounted) {
                                setState(() => _hour = selected.hour);
                              }
                            },
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Utwórz też listę zakupów'),
                            value: _createList,
                            onChanged:
                                _enabled
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
                          _automation?.lastError ?? 'Ostatni plan utworzony',
                        ),
                        subtitle:
                            _automation?.lastSuccessAt == null
                                ? null
                                : Text(
                                  DateFormat(
                                    'd MMMM yyyy, HH:mm',
                                    'pl_PL',
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
                    label: const Text('Zapisz ustawienia'),
                  ),
                  if (_enabled) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _runNow,
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: const Text('Wygeneruj teraz'),
                    ),
                  ],
                ],
              ),
    );
  }
}
