import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../l10n/market_locale.dart';
import '../../utils/campaign_calendar.dart';
import '../../widgets/campaign_icon.dart';

class AdminCampaignsScreen extends StatefulWidget {
  const AdminCampaignsScreen({super.key, this.market = 'PL', this.client});

  final String market;
  final ApiClient? client;

  @override
  State<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends State<AdminCampaignsScreen> {
  late ApiClient _client;
  int _generation = 0;
  int _marketEpoch = 0;
  final _busyIds = <String>{};

  String get _market => widget.market == 'GB' ? 'GB' : 'PL';
  String _path(String suffix, {String? query}) =>
      '/purchase-campaigns/admin$suffix?market=$_market${query == null ? '' : '&$query'}';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _offerUrl = TextEditingController();
  final _basePlanId = TextEditingController();
  final _androidOfferId = TextEditingController();
  List<dynamic> _campaigns = [];
  DateTimeRange? _dates;
  String _kind = 'premium';
  String _productId = 'premium_monthly';
  String _audience = 'all';
  String _platform = 'ios';
  int _percent = 30;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ApiClient();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminCampaignsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.market != widget.market ||
        oldWidget.client != widget.client) {
      _marketEpoch++;
      _client = widget.client ?? _client;
      _campaigns = [];
      _loading = true;
      _error = null;
      _saving = false;
      _busyIds.clear();
      _dates = null;
      _email.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _offerUrl.dispose();
    _basePlanId.dispose();
    _androidOfferId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final market = _market;
    try {
      final response = await _client.get(_path(''));
      if (!mounted || generation != _generation) return;
      final campaigns = (response as List).cast<Map<String, dynamic>>();
      if (campaigns.any((item) => (item['country_code'] ?? 'PL') != market)) {
        throw const FormatException('Odpowiedź zawiera kampanię innego rynku.');
      }
      setState(() {
        _campaigns = campaigns;
        _error = null;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = friendlyError(e, strings: context.strings));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final market = _market;
    final epoch = _marketEpoch;
    final missingStoreConfiguration =
        _platform == 'ios' && _kind == 'premium'
            ? _offerUrl.text.trim().isEmpty
            : _kind == 'premium' &&
                (_basePlanId.text.trim().isEmpty ||
                    _androidOfferId.text.trim().isEmpty);
    if (_name.text.trim().length < 3 ||
        _dates == null ||
        missingStoreConfiguration ||
        (_audience == 'user' && _email.text.trim().isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.campaignRequired)));
      return;
    }
    setState(() => _saving = true);
    try {
      final start = campaignBoundaryUtc(_dates!.start, market);
      final end = campaignBoundaryUtc(_dates!.end, market, followingDay: true);
      await _client.post(
        _path(''),
        body: {
          'name': _name.text.trim(),
          'kind': _kind,
          'product_id': _productId,
          'discount_percent': _percent,
          'audience': _audience,
          'target_email': _audience == 'user' ? _email.text.trim() : null,
          'starts_at': start.toUtc().toIso8601String(),
          'ends_at': end.toUtc().toIso8601String(),
          'platform': _platform,
          'ios_offer_url':
              _platform == 'ios' && _kind == 'premium'
                  ? _offerUrl.text.trim()
                  : null,
          'android_base_plan_id':
              _platform == 'android' && _kind == 'premium'
                  ? _basePlanId.text.trim()
                  : null,
          'android_offer_id':
              _platform == 'android' && _kind == 'premium'
                  ? _androidOfferId.text.trim()
                  : null,
        },
      );
      if (!mounted || market != _market || epoch != _marketEpoch) return;
      _name.clear();
      _offerUrl.clear();
      _basePlanId.clear();
      _androidOfferId.clear();
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (mounted && market == _market && epoch == _marketEpoch)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, strings: context.strings))),
        );
    } finally {
      if (mounted && market == _market && epoch == _marketEpoch)
        setState(() => _saving = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> campaign, bool value) async {
    final market = _market;
    final epoch = _marketEpoch;
    final id = campaign['id'].toString();
    if (!_busyIds.add(id)) return;
    setState(() {});
    try {
      if (value) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  campaign['platform'] == 'android'
                      ? context.strings.campaignConfirmGoogle
                      : context.strings.campaignConfirmApple,
                ),
                content: Text(
                  campaign['kind'] == 'points'
                      ? context.strings.campaignConfirmPoints(
                        campaign['platform'] == 'android'
                            ? 'Google Play'
                            : 'App Store Connect',
                      )
                      : context.strings.campaignConfirmPremium,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.strings.planCancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.strings.campaignConfirm),
                  ),
                ],
              ),
        );
        if (confirmed != true ||
            !mounted ||
            market != _market ||
            epoch != _marketEpoch)
          return;
      }
      await _client.patch(_path('/$id', query: 'is_active=$value'));
      if (mounted && market == _market && epoch == _marketEpoch) await _load();
    } catch (e) {
      if (mounted && market == _market && epoch == _marketEpoch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, strings: context.strings))),
        );
      }
    } finally {
      if (mounted && market == _market && epoch == _marketEpoch)
        setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _delete(Map<String, dynamic> campaign) async {
    final market = _market;
    final epoch = _marketEpoch;
    final id = campaign['id'].toString();
    if (!_busyIds.add(id)) return;
    setState(() {});
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(context.strings.campaignDeleteTitle),
              content: Text(
                context.strings.campaignDeleteBody('${campaign['name']}'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.strings.planCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.strings.productsDelete),
                ),
              ],
            ),
      );
      if (confirmed != true ||
          !mounted ||
          market != _market ||
          epoch != _marketEpoch)
        return;
      await _client.delete(_path('/$id'));
      if (mounted && market == _market && epoch == _marketEpoch) await _load();
    } catch (e) {
      if (mounted && market == _market && epoch == _marketEpoch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, strings: context.strings))),
        );
      }
    } finally {
      if (mounted && market == _market && epoch == _marketEpoch)
        setState(() => _busyIds.remove(id));
    }
  }

  String _cardDay(String value, {bool exclusiveEnd = false}) {
    final instant = DateTime.tryParse(value);
    if (instant == null) return '—';
    final day = campaignCalendarDay(
      instant,
      _market,
      exclusiveEnd: exclusiveEnd,
    );
    if (context.strings.localeName.startsWith('en')) {
      return MaterialLocalizations.of(context).formatCompactDate(day);
    }
    // Preserve the existing Polish card's ISO date style.
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.campaignTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _market == 'GB'
                ? context.strings.campaignMarketGb
                : context.strings.campaignMarketPl,
          ),
          const SizedBox(height: 8),
          Text(
            context.strings.campaignHeading,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(context.strings.campaignHelp),
          const SizedBox(height: 20),
          Row(
            children: [
              CampaignIcon(
                icon: Icons.workspace_premium,
                color: AppTheme.accentColor,
                discountPercent: _percent,
              ),
              const SizedBox(width: 20),
              CampaignIcon(
                icon: Icons.toll,
                color: AppTheme.accentColor,
                discountPercent: _percent,
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: context.strings.campaignName,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            itemHeight: null,
            value: _platform,
            decoration: InputDecoration(
              labelText: context.strings.campaignStore,
            ),
            items: [
              DropdownMenuItem(value: 'ios', child: Text('App Store (iOS)')),
              DropdownMenuItem(
                value: 'android',
                child: Text('Google Play (Android)'),
              ),
            ],
            onChanged:
                (value) => setState(() {
                  _platform = value ?? 'ios';
                  if (_kind == 'points') {
                    _audience = 'all';
                  }
                }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            itemHeight: null,
            value: _kind,
            decoration: InputDecoration(
              labelText: context.strings.campaignOffer,
            ),
            items: [
              DropdownMenuItem(
                value: 'premium',
                child: Text(context.strings.campaignSubscription),
              ),
              DropdownMenuItem(
                value: 'points',
                child: Text(context.strings.campaignPoints),
              ),
            ],
            onChanged:
                (value) => setState(() {
                  _kind = value ?? 'premium';
                  _productId =
                      _kind == 'premium' ? 'premium_monthly' : 'points_20';
                  if (_kind == 'points') {
                    _audience = 'all';
                  }
                }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            itemHeight: null,
            value: _productId,
            decoration: InputDecoration(
              labelText: context.strings.campaignProduct,
            ),
            items:
                (_kind == 'premium'
                        ? const [
                          'premium_weekly_v2',
                          'premium_monthly',
                          'premium_yearly',
                        ]
                        : const ['points_10', 'points_20', 'points_50'])
                    .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                    .toList(),
            onChanged:
                (value) => setState(() => _productId = value ?? _productId),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            isExpanded: true,
            itemHeight: null,
            value: _percent,
            decoration: InputDecoration(
              labelText: context.strings.campaignDiscount,
            ),
            items:
                const [10, 20, 30, 40, 50]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n%')))
                    .toList(),
            onChanged: (value) => setState(() => _percent = value ?? 30),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            itemHeight: null,
            value: _audience,
            decoration: InputDecoration(
              labelText: context.strings.campaignAudience,
            ),
            items: [
              DropdownMenuItem(
                value: 'all',
                child: Text(context.strings.campaignEveryone),
              ),
              DropdownMenuItem(
                value: 'user',
                child: Text(context.strings.campaignOneUser),
              ),
            ],
            onChanged:
                _kind == 'points'
                    ? null
                    : (value) => setState(() => _audience = value ?? 'all'),
          ),
          if (_audience == 'user') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.strings.campaignEmail,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final dates = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                initialDateRange: _dates,
              );
              if (dates != null && mounted) setState(() => _dates = dates);
            },
            icon: const Icon(Icons.date_range),
            label: Text(
              _dates == null
                  ? context.strings.campaignDates
                  : '${_dates!.start.day}.${_dates!.start.month}.${_dates!.start.year} – ${_dates!.end.day}.${_dates!.end.month}.${_dates!.end.year}',
            ),
          ),
          const SizedBox(height: 12),
          if (_platform == 'ios' && _kind == 'premium')
            TextField(
              controller: _offerUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: context.strings.campaignAppleUrl,
                helperText: context.strings.campaignAppleUrlHelp,
              ),
            )
          else if (_platform == 'android' && _kind == 'premium') ...[
            TextField(
              controller: _basePlanId,
              decoration: InputDecoration(
                labelText: context.strings.campaignBasePlan,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _androidOfferId,
              decoration: InputDecoration(
                labelText: context.strings.campaignAndroidOffer,
              ),
            ),
          ] else
            Text(
              context.strings.campaignPointsHelp(
                _platform == 'ios' ? 'App Store Connect' : 'Google Play',
              ),
              style: TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.add),
            label: Text(
              _saving
                  ? context.strings.campaignSaving
                  : context.strings.campaignCreate,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.strings.campaignSaved,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!, style: TextStyle(color: AppTheme.errorColor)),
          if (!_loading && _campaigns.isEmpty)
            Text(context.strings.campaignEmpty),
          for (final item in _campaigns)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CampaignIcon(
                      icon:
                          item['kind'] == 'points'
                              ? Icons.toll
                              : Icons.workspace_premium,
                      color: AppTheme.accentColor,
                      discountPercent: item['discount_percent'] as int?,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${item['product_id']} • ${item['audience'] == 'all' ? context.strings.campaignEveryone : item['target_email']} • ${item['platform'] == 'android' ? 'Google Play' : 'App Store'}',
                          ),
                          Text(
                            '${_cardDay(item['starts_at'] as String)} – ${_cardDay(item['ends_at'] as String, exclusiveEnd: true)}',
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(context.strings.campaignActive),
                                    Switch.adaptive(
                                      value: item['is_active'] == true,
                                      onChanged:
                                          _busyIds.contains(
                                                item['id'].toString(),
                                              )
                                              ? null
                                              : (value) => _toggle(
                                                item as Map<String, dynamic>,
                                                value,
                                              ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: context.strings.campaignDeleteTooltip,
                                onPressed:
                                    _busyIds.contains(item['id'].toString())
                                        ? null
                                        : () => _delete(
                                          item as Map<String, dynamic>,
                                        ),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
