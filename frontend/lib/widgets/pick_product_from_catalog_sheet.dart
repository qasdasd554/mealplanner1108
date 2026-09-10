import 'dart:async';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

/// Wynik wyboru produktu z katalogu — nazwa, ilość i wyliczone wartości
/// odżywcze gotowe do wstawienia w formularz dziennika.
class PickedCatalogProduct {
  final String name;
  final double grams;
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  const PickedCatalogProduct({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });
}

/// Okno wyszukiwania produktu w katalogu — domyka obietnicę złożoną przy
/// przycisku "Dodaj produkt": zgłoszony (i zatwierdzony) produkt miał być
/// możliwy do wybrania w Śledzeniu, ale nigdzie w aplikacji nie było
/// faktycznej wyszukiwarki, która by to umożliwiała. Ten widget to
/// naprawia — szuka po tym samym katalogu (`GET /products`), z którego
/// korzysta ekran "Baza produktów", więc własne zatwierdzone zgłoszenia
/// pojawiają się tu na równi z produktami oficjalnymi.
class PickProductFromCatalogSheet extends StatefulWidget {
  const PickProductFromCatalogSheet({super.key});

  @override
  State<PickProductFromCatalogSheet> createState() =>
      _PickProductFromCatalogSheetState();
}

class _PickProductFromCatalogSheetState
    extends State<PickProductFromCatalogSheet> {
  final ApiClient _client = ApiClient();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Product> _results = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    // Odczekujemy chwilę po ostatnim znaku, zamiast odpytywać serwer
    // przy KAŻDYM naciśnięciu klawisza — przy szybkim pisaniu to
    // dziesiątki zbędnych żądań zamiast jednego.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final path = query.trim().isEmpty
          ? '/products?limit=30'
          : '/products?search=${Uri.encodeQueryComponent(query.trim())}&limit=30';
      final response = await _client.get(path);
      if (!mounted) return;
      setState(() {
        _results = (response as List)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProduct(Product product) async {
    final grams = await showDialog<double>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(
          text: product.defaultQuantity > 0
              ? product.defaultQuantity.toStringAsFixed(0)
              : '100',
        );
        return AlertDialog(
          title: Text(product.name),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText:
                  'Ilość (${product.unit == 'ml' || product.unit == 'l' ? 'ml' : 'g'})',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                final val = double.tryParse(controller.text.replaceAll(',', '.'));
                Navigator.pop(ctx, val);
              },
              child: const Text('Dalej'),
            ),
          ],
        );
      },
    );
    if (grams == null || grams <= 0 || !mounted) return;

    // Jednostka bazowa produktu bywa "l"/"kg" (duże opakowanie) — okno
    // pyta zawsze o ml/g dla precyzji, więc gdy trzeba, przeliczamy na
    // jednostkę, w której faktycznie podane jest nutritionPer100 (zawsze
    // "na 100 g/ml", niezależnie od jednostki opakowania).
    final n = product.nutritionPer100;
    final factor = grams / 100.0;

    Navigator.of(context).pop(
      PickedCatalogProduct(
        name: product.name,
        grams: grams,
        kcal: n.kcal * factor,
        protein: n.protein * factor,
        fat: n.fat * factor,
        carbs: n.carbs * factor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: const InputDecoration(
                  hintText: 'Szukaj produktu...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _isLoading && _results.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: TextStyle(color: AppTheme.textSecondary)),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                'Brak produktów pasujących do wyszukiwania.',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final p = _results[index];
                                return ListTile(
                                  title: Text(p.name),
                                  subtitle: Text(
                                    '${p.nutritionPer100.kcal.round()} kcal / 100${p.unit == 'ml' || p.unit == 'l' ? 'ml' : 'g'}'
                                    '${p.brand != null && p.brand!.isNotEmpty ? ' · ${p.brand}' : ''}',
                                  ),
                                  onTap: () => _pickProduct(p),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}
