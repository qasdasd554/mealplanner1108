import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/market_locale.dart';
import '../../l10n/recipe_content.dart';
import '../../l10n/measure_labels.dart';
import 'package:provider/provider.dart';

import '../../providers/shopping_list_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/product.dart';
import '../../services/pantry_service.dart';
import '../../services/product_search_service.dart';
import '../../widgets/barcode_destination_sheet.dart';
import '../../widgets/premium_feature_tag.dart';
import '../batch_barcode_scanner_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../utils/quantity_formatter.dart';
import '../../utils/product_measures.dart';
import '../../widgets/product_amount_picker.dart';

/// Spiżarnia — trwała lista produktów, które użytkownik faktycznie ma w
/// domu. Źródło dla "Co ugotować z tego, co mam" — zamiast wyszukiwać
/// składniki za każdym razem od nowa, wystarczy raz zbudować spiżarnię i
/// aktualizować ją na bieżąco.
class PantryScreen extends StatefulWidget {
  final bool openAddOnStart;
  final PantryService? service;
  final ProductSearchService? searchService;

  const PantryScreen({
    super.key,
    this.openAddOnStart = false,
    this.service,
    this.searchService,
  });

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  late final PantryService _pantryService = widget.service ?? PantryService();
  List<PantryItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _deletingIds = {};
  // Row IDs, not product IDs: re-adding the same product creates a new UUID.
  // Keep completed deletions hidden from late refreshes for this screen's life.
  final Set<String> _deletedIds = {};

  void _refreshShoppingLists() {
    final shopping = context.read<ShoppingListProvider>();
    unawaited(shopping.loadAllLists(preferredListId: shopping.selectedListId));
  }

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.openAddOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddDialog();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items = await _pantryService.getPantry();
      if (!mounted) return;
      setState(
        () =>
            _items =
                items
                    .where(
                      (item) =>
                          !_deletingIds.contains(item.id) &&
                          !_deletedIds.contains(item.id),
                    )
                    .toList(),
      );
    } catch (e) {
      if (!mounted) return;
      // UWAGA (naprawa wzorca błędu): pokazujemy PRAWDZIWY komunikat
      // błędu zamiast po cichu zostawiać pustą listę — wcześniejsza
      // wersja ekranu wyboru składników cicho łykała błędy (catch (_)),
      // co uniemożliwiało zdiagnozowanie prawdziwej przyczyny problemów.
      setState(
        () => _errorMessage = friendlyError(e, strings: context.strings),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(PantryItem item) async {
    // Optymistyczne usunięcie z UI, z przywróceniem przy błędzie —
    // czuje się natychmiastowe, bez migania stanu ładowania.
    final removedIndex = _items.indexOf(item);
    if (_deletingIds.contains(item.id)) return;
    setState(() {
      _deletingIds.add(item.id);
      _items.remove(item);
    });
    try {
      await _pantryService.deleteItem(item.id);
      if (!mounted) return;
      _deletedIds.add(item.id);
      _refreshShoppingLists();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Other optimistic removals or a refresh may have changed the list.
        if (!_items.any((existing) => existing.id == item.id)) {
          _items.insert(removedIndex.clamp(0, _items.length), item);
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    } finally {
      _deletingIds.remove(item.id);
    }
  }

  /// Prosty dialog do wpisania/zmiany ilości produktu już zapisanego w
  /// spiżarni — jednostka domyślnie wypełniona z produktu (np. "kg",
  /// "szt"), użytkownik wpisuje samą liczbę.
  Future<void> _editQuantity(PantryItem item) async {
    final amount = await showProductAmountPicker(
      context,
      product: item.product,
      initialQuantity: item.quantity ?? 1,
      initialUnit: item.unit,
    );
    if (amount == null) return;

    try {
      final updated = await _pantryService.updateQuantity(
        item.id,
        quantity: amount.quantity,
        unit: amount.measure.code,
      );
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((i) => i.id == item.id);
        if (index != -1) _items[index] = updated;
      });
      _refreshShoppingLists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  Future<void> _showAddDialog() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => _AddToPantrySheet(
            pantryService: _pantryService,
            searchService: widget.searchService,
          ),
    );
    if (added == true) {
      _load();
      if (mounted) _refreshShoppingLists();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.pantry)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: Text(context.strings.pantryAddProduct),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 48,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _load,
                            child: Text(context.strings.productsRetry),
                          ),
                        ],
                      ),
                    ),
                  )
                  : _items.isEmpty
                  ? ListView(
                    // ListView (nie Center) — żeby RefreshIndicator
                    // działał nawet przy pustej spiżarni.
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 80,
                          horizontal: 32,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.kitchen_outlined,
                              size: 56,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.strings.pantryEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryColor,
                          ),
                          title: Text(item.product.displayName(context)),
                          subtitle: Text(
                            item.quantity != null
                                ? '${formatQuantity(item.quantity!, item.unit ?? item.product.unit)} '
                                    '${context.strings.measureQuantityLabel(item.unit ?? item.product.unit, fallback: productMeasureLabel(item.unit ?? item.product.unit), amount: item.quantity)}'
                                : context.strings.pantryEnterAmount,
                            style: TextStyle(
                              color:
                                  item.quantity != null
                                      ? AppTheme.textSecondary
                                      : AppTheme.primaryColor,
                              fontStyle:
                                  item.quantity != null
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                            ),
                          ),
                          onTap: () => _editQuantity(item),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _delete(item),
                            tooltip: context.strings.pantryRemove,
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }
}

/// Dolny panel do wyszukania i dodania produktów do spiżarni. Osobny
/// widget (nie metoda) — bo potrzebuje własnego stanu (wyniki
/// wyszukiwania), inaczej `showModalBottomSheet`'s builder nie
/// odświeżałby się poprawnie przy wpisywaniu tekstu.
class _AddToPantrySheet extends StatefulWidget {
  final PantryService pantryService;
  final ProductSearchService? searchService;

  const _AddToPantrySheet({required this.pantryService, this.searchService});

  @override
  State<_AddToPantrySheet> createState() => _AddToPantrySheetState();
}

class _AddToPantrySheetState extends State<_AddToPantrySheet> {
  late final ProductSearchService _searchService =
      widget.searchService ?? ProductSearchService();
  final TextEditingController _controller = TextEditingController();
  List<Product> _results = [];
  bool _isSearching = false;
  bool _isSaving = false;
  int _searchGeneration = 0;

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _results = [];
      _isSearching = true;
    });
    try {
      final results = await _searchService.search(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _add(Product product) async {
    final amount = await showProductAmountPicker(
      context,
      product: product,
      initialQuantity: 1,
      initialUnit: product.servingQuantity != null ? 'opak' : product.unit,
    );
    if (amount == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await widget.pantryService.addItems(
        [product.id],
        quantity: amount.quantity,
        unit: amount.measure.code,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(context.strings.pantrySaved(product.name)),
          ),
        );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  Future<void> _scanAndAdd() async {
    await scanProductWithDestination(
      context,
      onPantryAdded: () {
        if (context.mounted) Navigator.of(context).pop(true);
      },
    );
  }

  Future<void> _scanBatch() async {
    final hasPremium =
        context.read<AuthProvider>().currentUser?.hasPremiumAccess ?? false;
    if (!hasPremium) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const BatchBarcodeScannerScreen(previewOnly: true),
        ),
      );
      return;
    }

    final completed = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const BatchBarcodeScannerScreen()),
    );
    if (!mounted || completed == null || completed == 0) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.strings.addToPantry,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _scanAndAdd,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(context.strings.pantryScanBarcode),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isSaving ? null : _scanBatch,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_2, size: 19),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.strings.pantryScanMany,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const PremiumFeatureTag(fontSize: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: context.strings.pantrySearchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child:
                  _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _results.isEmpty
                      ? Center(
                        child: Text(
                          _controller.text.trim().length < 2
                              ? context.strings.pantrySearchStart
                              : context.strings.pantrySearchEmpty,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                      : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final product = _results[index];
                          return ListTile(
                            title: Text(product.displayName(context)),
                            trailing:
                                _isSaving
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.add_circle_outline),
                            onTap: _isSaving ? null : () => _add(product),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
