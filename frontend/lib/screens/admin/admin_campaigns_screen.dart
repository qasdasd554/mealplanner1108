import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../widgets/campaign_icon.dart';

class AdminCampaignsScreen extends StatefulWidget {
  const AdminCampaignsScreen({super.key});

  @override
  State<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends State<AdminCampaignsScreen> {
  final _client = ApiClient();
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
    _load();
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
    try {
      final response = await _client.get('/purchase-campaigns/admin');
      if (!mounted) return;
      setState(() {
        _campaigns = response as List<dynamic>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Uzupełnij nazwę, daty, konfigurację oferty sklepu i odbiorcę.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final start = DateTime(
        _dates!.start.year,
        _dates!.start.month,
        _dates!.start.day,
      );
      final end = DateTime(
        _dates!.end.year,
        _dates!.end.month,
        _dates!.end.day + 1,
      );
      await _client.post(
        '/purchase-campaigns/admin',
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
      _name.clear();
      _offerUrl.clear();
      _basePlanId.clear();
      _androidOfferId.clear();
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> campaign, bool value) async {
    if (value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                campaign['platform'] == 'android'
                    ? 'Potwierdź ofertę w Google Play'
                    : 'Potwierdź ofertę w App Store',
              ),
              content: Text(
                campaign['kind'] == 'points'
                    ? 'Włącz tylko po ustawieniu czasowej ceny tego pakietu punktów w ${campaign['platform'] == 'android' ? 'Google Play' : 'App Store Connect'} dla wszystkich użytkowników. Cena w aplikacji pochodzi bezpośrednio ze sklepu.'
                    : 'Włącz tylko wtedy, gdy wskazana oferta sklepu jest aktywna, ma dokładnie ten rabat i obejmuje właściwy produkt. Aplikacja nie zmienia ceny samodzielnie.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Potwierdzam'),
                ),
              ],
            ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      await _client.patch(
        '/purchase-campaigns/admin/${campaign['id']}?is_active=$value',
      );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _delete(Map<String, dynamic> campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Usunąć kampanię?'),
            content: Text(
              'Kampania „${campaign['name']}” zniknie z panelu. Ofertę w sklepie trzeba wyłączyć osobno.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Usuń'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _client.delete('/purchase-campaigns/admin/${campaign['id']}');
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kampanie')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Promocja Premium i punktów',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Szarfy pojawiają się na ikonkach w panelu Premium. Subskrypcja iOS otwiera kod ofertowy Apple, a Android wybiera ofertę Google Play. Dla punktów ustaw czasową cenę produktu w odpowiednim sklepie dla wszystkich.',
          ),
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
            decoration: const InputDecoration(labelText: 'Nazwa kampanii'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _platform,
            decoration: const InputDecoration(labelText: 'Sklep'),
            items: const [
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
            value: _kind,
            decoration: const InputDecoration(labelText: 'Oferta'),
            items: const [
              DropdownMenuItem(
                value: 'premium',
                child: Text('Subskrypcja Premium'),
              ),
              DropdownMenuItem(value: 'points', child: Text('Punkty premium')),
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
            value: _productId,
            decoration: const InputDecoration(
              labelText: 'Pakiet objęty ofertą',
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
            value: _percent,
            decoration: const InputDecoration(labelText: 'Rabat'),
            items:
                const [10, 20, 30, 40, 50]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n%')))
                    .toList(),
            onChanged: (value) => setState(() => _percent = value ?? 30),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _audience,
            decoration: const InputDecoration(labelText: 'Odbiorcy'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Wszyscy')),
              DropdownMenuItem(value: 'user', child: Text('Jeden użytkownik')),
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
              decoration: const InputDecoration(
                labelText: 'E-mail użytkownika',
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
                  ? 'Wybierz termin'
                  : '${_dates!.start.day}.${_dates!.start.month}.${_dates!.start.year} – ${_dates!.end.day}.${_dates!.end.month}.${_dates!.end.year}',
            ),
          ),
          const SizedBox(height: 12),
          if (_platform == 'ios' && _kind == 'premium')
            TextField(
              controller: _offerUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link do kodu ofertowego Apple',
                helperText: 'Link apps.apple.com/redeem?ctx=offercodes…',
              ),
            )
          else if (_platform == 'android' && _kind == 'premium') ...[
            TextField(
              controller: _basePlanId,
              decoration: const InputDecoration(
                labelText: 'Google Play: ID planu bazowego',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _androidOfferId,
              decoration: const InputDecoration(
                labelText: 'Google Play: ID oferty',
              ),
            ),
          ] else
            Text(
              'Najpierw zaplanuj czasową obniżkę ceny tego pakietu punktów w ${_platform == 'ios' ? 'App Store Connect' : 'Google Play'}. Kampania pokazuje szarfę, ale kwotę zawsze pobiera bezpośrednio ze sklepu.',
              style: TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.add),
            label: Text(_saving ? 'Zapisuję…' : 'Utwórz kampanię (wyłączoną)'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Zapisane kampanie',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!, style: TextStyle(color: AppTheme.errorColor)),
          if (!_loading && _campaigns.isEmpty) const Text('Brak kampanii.'),
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
                            '${item['product_id']} • ${item['audience'] == 'all' ? 'Wszyscy' : item['target_email']} • ${item['platform'] == 'android' ? 'Google Play' : 'App Store'}',
                          ),
                          Text(
                            '${(item['starts_at'] as String).substring(0, 10)} – ${(item['ends_at'] as String).substring(0, 10)}',
                          ),
                          Row(
                            children: [
                              const Text('Aktywna'),
                              Switch.adaptive(
                                value: item['is_active'] == true,
                                onChanged:
                                    (value) => _toggle(
                                      item as Map<String, dynamic>,
                                      value,
                                    ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Usuń kampanię',
                                onPressed:
                                    () => _delete(item as Map<String, dynamic>),
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
