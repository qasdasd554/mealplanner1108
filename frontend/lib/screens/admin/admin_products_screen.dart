import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

/// Panel moderacji produktów zgłoszonych przez użytkowników.
///
/// Do czasu zatwierdzenia produkt jest widoczny WYŁĄCZNIE dla osoby,
/// która go dodała — może go już używać w dzienniku, ale nie zaśmieca
/// katalogu pozostałym.
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final ApiClient _client = ApiClient();
  List<dynamic> _products = [];
  bool _isLoading = true;
  String? _loadError;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await _client.get('/products/admin/pending');
      if (!mounted) return;
      if (response is! List)
        throw const FormatException('Nieprawidłowa odpowiedź serwera');
      setState(() {
        _products = response;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = friendlyError(e));
    } finally {
      // finally, żeby kółko zniknęło niezależnie od wyniku żądania.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _review(String id, bool approve) async {
    setState(() => _busy.add(id));
    try {
      await _client.post('/products/admin/$id/review?approve=$approve');
      if (!mounted) return;
      setState(() {
        _products.removeWhere((p) => p['id'] == id);
        _busy.remove(id);
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              approve ? 'Produkt dodany do katalogu' : 'Produkt odrzucony',
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zgłoszone produkty')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Spróbuj ponownie'),
                      ),
                    ],
                  ),
                ),
              )
              : _products.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 56,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Brak produktów oczekujących na sprawdzenie.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Odśwież zgłoszenia'),
                      ),
                    ],
                  ),
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index] as Map<String, dynamic>;
                    final id = p['id'] as String;
                    final isBusy = _busy.contains(id);
                    final nutrition = p['nutrition_per_100'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'] as String? ?? '—',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if ((p['brand'] as String?)?.isNotEmpty ?? false)
                                p['brand'],
                              '${p['submitted_price'] ?? '—'} zł',
                              p['unit'] ?? '',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            nutrition == null
                                ? 'Bez wartości odżywczych'
                                : 'Na 100 g: ${nutrition['kcal']} kcal · '
                                    'B ${nutrition['protein']} · '
                                    'T ${nutrition['fat']} · '
                                    'W ${nutrition['carbs']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed:
                                      isBusy ? null : () => _review(id, false),
                                  child: Text(
                                    'Odrzuć',
                                    style: TextStyle(
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      isBusy ? null : () => _review(id, true),
                                  child:
                                      isBusy
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Text('Akceptuj'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
