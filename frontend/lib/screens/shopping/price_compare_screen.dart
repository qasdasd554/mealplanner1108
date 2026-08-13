import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/price_compare_service.dart';

class PriceCompareScreen extends StatefulWidget {
  final String mealPlanId;

  const PriceCompareScreen({Key? key, required this.mealPlanId}) : super(key: key);

  @override
  _PriceCompareScreenState createState() => _PriceCompareScreenState();
}

class _PriceCompareScreenState extends State<PriceCompareScreen> {
  final PriceCompareService _priceCompareService = PriceCompareService();
  bool _isLoading = true;
  List<PriceComparisonResult> _results = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComparison();
  }

  Future<void> _loadComparison() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _priceCompareService.comparePrices(widget.mealPlanId);
      // Sort by price ascending
      results.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
      
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Nie udało się załadować porównania: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Porównanie cen'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadComparison,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(child: Text('Brak danych do porównania.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        final isCheapest = index == 0;
        
        return Card(
          elevation: isCheapest ? 4.0 : 1.0,
          color: isCheapest ? Colors.green.shade50 : null,
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            leading: const Icon(Icons.store, size: 40, color: Colors.grey),
            title: Text(
              result.storeName,
              style: TextStyle(
                fontWeight: isCheapest ? FontWeight.bold : FontWeight.normal,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              '${result.items.length} ${result.items.length == 1 ? "produkt" : "produktów"} • dotknij, aby zobaczyć listę'
              '${result.savingsVsMostExpensive > 0 ? " • oszczędzasz ${result.savingsVsMostExpensive.toStringAsFixed(2)} zł" : ""}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isCheapest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Najtaniej',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${result.totalPrice.toStringAsFixed(2)} zł',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isCheapest ? Colors.green.shade800 : null,
                  ),
                ),
              ],
            ),
            children: [
              const Divider(height: 1),
              ...result.items.map((item) {
                return ListTile(
                  dense: true,
                  title: Text(item.displayName, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${item.quantityNeeded.toStringAsFixed(item.quantityNeeded == item.quantityNeeded.roundToDouble() ? 0 : 1)} ${item.unit}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Text(
                    '${item.priceInStore.toStringAsFixed(2)} zł',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
