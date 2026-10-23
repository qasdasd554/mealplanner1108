import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/market_locale.dart';
import '../../providers/auth_provider.dart';
import '../../services/price_compare_service.dart';
import '../../providers/meal_plan_provider.dart';
import '../../utils/market_money.dart';
import '../../services/api_client.dart';
import '../../utils/error_utils.dart';
import '../../widgets/price_source_info.dart';
import '../../widgets/store_price_comparison_card.dart';

class PriceCompareScreen extends StatefulWidget {
  final String? mealPlanId;
  final String? shoppingListId;
  final String? shoppingListCurrencyCode;
  final PriceCompareService? service;

  const PriceCompareScreen({Key? key, required this.mealPlanId, this.service})
    : shoppingListId = null,
      shoppingListCurrencyCode = null,
      super(key: key);

  /// [shoppingListId] is the public API identifier (ShoppingList.mealPlanId),
  /// not the database row ID. No plan entries are fetched or regenerated.
  const PriceCompareScreen.shoppingList({
    super.key,
    required this.shoppingListId,
    required String currencyCode,
    this.service,
  }) : assert(shoppingListId != null),
       shoppingListCurrencyCode = currencyCode,
       mealPlanId = null;

  @override
  _PriceCompareScreenState createState() => _PriceCompareScreenState();
}

class _PriceCompareScreenState extends State<PriceCompareScreen> {
  late PriceCompareService _priceCompareService;
  int _requestGeneration = 0;
  bool _isLoading = true;
  bool _isSwitchingStore = false;
  List<PriceComparisonResult> _results = [];
  String? _error;
  String get _currencyCode =>
      widget.shoppingListCurrencyCode ??
      currencyForAccountCountry(
        context.read<AuthProvider>().currentUser?.countryCode,
      );

  ({String? userId, int session}) get _accountStamp => (
    userId: context.read<AuthProvider>().currentUser?.id,
    session: ApiClient().sessionGeneration,
  );

  Future<void> _switchToStore(PriceComparisonResult result) async {
    if (_isSwitchingStore) return;
    final generation = _requestGeneration;
    final account = _accountStamp;
    setState(() => _isSwitchingStore = true);
    var success = false;
    String? error;
    try {
      if (result.currencyCode != _currencyCode) {
        throw const FormatException('Price comparison currency mismatch');
      }
      if (widget.shoppingListId != null) {
        await _priceCompareService.switchShoppingListStore(
          widget.shoppingListId!,
          result.storeId,
          expectedCurrencyCode: _currencyCode,
        );
        success = true;
      } else {
        final provider = context.read<MealPlanProvider>();
        success = await provider.updateStore(
          widget.mealPlanId!,
          result.storeId,
        );
        error = provider.errorMessage;
      }
    } catch (failure) {
      error =
          failure is FormatException
              ? (mounted ? context.strings.priceCompareCurrencyError : null)
              : friendlyError(failure);
    }
    if (!mounted || generation != _requestGeneration) return;
    if (_accountStamp != account) {
      setState(() {
        _isSwitchingStore = false;
        _results = [];
        _error = context.strings.priceCompareCurrencyError;
      });
      return;
    }
    setState(() => _isSwitchingStore = false);
    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              widget.shoppingListId != null
                  ? context.strings.priceCompareListSwitchSuccess(
                    result.storeName,
                  )
                  : context.strings.priceCompareSwitchSuccess(result.storeName),
            ),
          ),
        );
      if (widget.shoppingListId != null) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pop();
      }
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(error ?? context.strings.priceCompareSwitchError),
          ),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _priceCompareService = widget.service ?? PriceCompareService();
    _loadComparison();
  }

  @override
  void didUpdateWidget(covariant PriceCompareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mealPlanId != oldWidget.mealPlanId ||
        widget.shoppingListId != oldWidget.shoppingListId ||
        widget.shoppingListCurrencyCode != oldWidget.shoppingListCurrencyCode ||
        widget.service != oldWidget.service) {
      _priceCompareService = widget.service ?? PriceCompareService();
      _loadComparison();
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    super.dispose();
  }

  Future<void> _loadComparison() async {
    final generation = ++_requestGeneration;
    final account = _accountStamp;
    setState(() {
      _isLoading = true;
      _isSwitchingStore = false;
      _results = [];
      _error = null;
    });

    try {
      final expectedCurrency = _currencyCode;
      final results =
          widget.shoppingListId != null
              ? await _priceCompareService.compareShoppingList(
                widget.shoppingListId!,
                expectedCurrencyCode: expectedCurrency,
              )
              : await _priceCompareService.comparePrices(
                widget.mealPlanId!,
                expectedCurrencyCode: expectedCurrency,
              );
      if (!mounted || generation != _requestGeneration) return;
      if (_currencyCode != expectedCurrency || _accountStamp != account) {
        throw const FormatException('Account market changed during request');
      }
      results.sort(PriceComparisonResult.compareForDisplay);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error =
            e is FormatException
                ? context.strings.priceCompareCurrencyError
                : context.strings.priceCompareLoadError(e.toString());
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.priceCompareTitle),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            tooltip: context.strings.priceCompareSourcesTooltip,
            onPressed: _showPriceSources,
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
              child: Text(context.strings.priceCompareRetry),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(child: Text(context.strings.priceCompareEmpty));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              context.strings.priceCompareIntro,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }
        final result = _results[index - 1];
        return StorePriceComparisonCard(
          result: result,
          isSwitchingStore: _isSwitchingStore,
          allowUnpricedListSwitch: widget.shoppingListId != null,
          switchStoreLabel:
              widget.shoppingListId != null
                  ? context.strings.priceCompareListSwitchStore
                  : null,
          onSwitchStore: () => _switchToStore(result),
        );
      },
    );
  }

  Future<void> _showPriceSources() {
    if (!context.strings.localeName.startsWith('en')) {
      return showPriceSourceInfo(context);
    }
    final strings = context.strings;
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(strings.priceCompareSourceTitle),
            content: SingleChildScrollView(
              child: Text(strings.priceCompareSourceBody),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.priceCompareSourceClose),
              ),
            ],
          ),
    );
  }
}
