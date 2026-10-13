import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/price_compare_service.dart';
import '../../providers/meal_plan_provider.dart';
import '../../widgets/price_source_info.dart';
import '../../widgets/store_price_comparison_card.dart';

class PriceCompareScreen extends StatefulWidget {
  final String mealPlanId;

  const PriceCompareScreen({Key? key, required this.mealPlanId})
    : super(key: key);

  @override
  _PriceCompareScreenState createState() => _PriceCompareScreenState();
}

class _PriceCompareScreenState extends State<PriceCompareScreen> {
  final PriceCompareService _priceCompareService = PriceCompareService();
  bool _isLoading = true;
  bool _isSwitchingStore = false;
  List<PriceComparisonResult> _results = [];
  String? _error;

  Future<void> _switchToStore(PriceComparisonResult result) async {
    setState(() => _isSwitchingStore = true);
    final provider = Provider.of<MealPlanProvider>(context, listen: false);
    final success = await provider.updateStore(
      widget.mealPlanId,
      result.storeId,
    );
    if (!mounted) return;
    setState(() => _isSwitchingStore = false);
    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text('Plan przełączony na ${result.storeName}'),
          ),
        );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              provider.errorMessage ?? 'Nie udało się przełączyć sklepu',
            ),
          ),
        );
    }
  }

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
      final results = await _priceCompareService.comparePrices(
        widget.mealPlanId,
      );
      results.sort(PriceComparisonResult.compareForDisplay);

      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
        actions: [
          IconButton(
            tooltip: 'Źródła cen i marek',
            onPressed: () => showPriceSourceInfo(context),
            icon: const Icon(Icons.info_outline),
          ),
        ],
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
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Porównujemy koszt całej listy. „~” oznacza cenę orientacyjną. '
              'Dostępność i aktualną cenę potwierdź w wybranym sklepie.',
              style: TextStyle(fontSize: 12),
            ),
          );
        }
        final result = _results[index - 1];
        return StorePriceComparisonCard(
          result: result,
          isSwitchingStore: _isSwitchingStore,
          onSwitchStore: () => _switchToStore(result),
        );
      },
    );
  }
}
