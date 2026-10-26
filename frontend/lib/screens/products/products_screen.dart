import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/market_locale.dart';
import '../../l10n/recipe_content.dart';
import '../../l10n/measure_labels.dart';
import '../../utils/market_money.dart';
import '../../utils/quantity_formatter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/store.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../services/api_client.dart';
import '../../services/product_search_service.dart';
import '../../services/store_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../widgets/submit_product_sheet.dart';
import '../../widgets/price_source_info.dart';
import '../../utils/store_price_labels.dart';
import '../../widgets/premium_feature_tag.dart';
import '../../widgets/product_contribution_reward_banner.dart';
import '../../widgets/barcode_destination_sheet.dart';
import '../batch_barcode_scanner_screen.dart';

/// Ekran produktów w trzech zakładkach: „Sklep” (oferta wybranego sklepu),
/// „Katalog” (wszystkie produkty żywieniowe) i „Moje” (własne zgłoszenia).
///
/// NAPRAWA BRAKUJĄCEJ FUNKCJI: zgłoszony produkt zapisywał się w bazie,
/// ale nigdzie w aplikacji nie było miejsca, które by go pokazało —
/// zakładka „Sklep” celowo pokazuje wyłącznie produkty powiązane ze
/// sklepem, a zgłoszenie takiego powiązania nie ma. Druga zakładka
/// domyka tę lukę.
class ProductsScreen extends StatefulWidget {
  final ProductSearchService? catalogueService;
  final StoreService? storeService;
  final ApiClient? client;
  const ProductsScreen({
    super.key,
    this.catalogueService,
    this.storeService,
    this.client,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _myProductsRefresh = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final added = await scanProductWithDestination(context);
    if (added && mounted) {
      setState(() => _myProductsRefresh++);
      _tabController.animateTo(2);
    }
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.strings.productsProcessed(completed))),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.productsTitle),
        actions: [
          IconButton(
            tooltip: context.strings.productsPriceSources,
            onPressed: () => showPriceSourceInfo(context),
            icon: const Icon(Icons.info_outline),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.strings.productsShopTab),
            Tab(text: context.strings.productsCatalogueTab),
            Tab(text: context.strings.productsMineTab),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder:
            (context, constraints) => Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.textScalerOf(context).scale(14) > 18.2
                            ? constraints.maxHeight * 0.45
                            : double.infinity,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ProductContributionRewardBanner(),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _scanBarcode,
                            icon: const Icon(Icons.barcode_reader),
                            label: Text(
                              context.strings.productsScan,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton(
                            onPressed: _scanBatch,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.qr_code_2, size: 19),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    context.strings.productsBatchScan,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const PremiumFeatureTag(fontSize: 8),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _StoreProductsTab(service: widget.storeService),
                      _CatalogProductsTab(service: widget.catalogueService),
                      _MyProductsTab(
                        key: ValueKey(_myProductsRefresh),
                        client: widget.client,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

/// Pełny katalog żywieniowy. Trafiają tu także produkty restauracyjne i
/// składniki niezwiązane z konkretnym supermarketem.
class _CatalogProductsTab extends StatefulWidget {
  final ProductSearchService? service;
  const _CatalogProductsTab({this.service});

  @override
  State<_CatalogProductsTab> createState() => _CatalogProductsTabState();
}

class _CatalogProductsTabState extends State<_CatalogProductsTab> {
  static const int _pageSize = 50;

  late final ProductSearchService _service;
  final TextEditingController _searchController = TextEditingController();
  final List<Product> _products = [];
  Timer? _searchDebounce;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductSearchService();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_isLoading && !reset) return;
    final generation = reset ? ++_requestGeneration : _requestGeneration;
    final skip = reset ? 0 : _products.length;
    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) {
        _products.clear();
        _hasMore = true;
      }
    });

    try {
      final page = await _service.list(
        query: _searchController.text,
        skip: skip,
        limit: _pageSize,
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _products.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _error = friendlyError(e, strings: context.strings));
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String _) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(reset: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.strings.productsBrandSearch,
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchController.text.isEmpty
                      ? null
                      : IconButton(
                        tooltip: context.strings.productsClear,
                        onPressed: () {
                          _searchController.clear();
                          _load(reset: true);
                        },
                        icon: const Icon(Icons.close),
                      ),
            ),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _products.isEmpty) {
      return _ScrollableProductMessage(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _load(reset: true),
                child: Text(context.strings.productsRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(child: Text(context.strings.productsNotFound));
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _products.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _products.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => _load(reset: false),
                child:
                    _isLoading
                        ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(context.strings.productsShowMore),
              ),
            );
          }
          return _CatalogProductTile(product: _products[index]);
        },
      ),
    );
  }
}

class _CatalogProductTile extends StatelessWidget {
  const _CatalogProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final nutrition = product.nutritionPer100;
    final baseUnit = product.unit == 'ml' || product.unit == 'l' ? 'ml' : 'g';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.displayName(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (product.brand?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.brand!,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${context.strings.nutritionMacroLine(nutrition.knownValue('kcal')?.toStringAsFixed(0) ?? '—', nutrition.knownValue('protein')?.toStringAsFixed(1) ?? '—', nutrition.knownValue('fat')?.toStringAsFixed(1) ?? '—', nutrition.knownValue('carbs')?.toStringAsFixed(1) ?? '—')} / 100$baseUnit',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dawna zawartość ekranu — katalog produktów wybranego sklepu.
class _StoreProductsTab extends StatefulWidget {
  final StoreService? service;
  const _StoreProductsTab({this.service});

  @override
  State<_StoreProductsTab> createState() => _StoreProductsTabState();
}

class _StoreProductsTabState extends State<_StoreProductsTab> {
  late final StoreService _storeService;

  List<StoreProduct> _products = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _selectedStoreId;
  Timer? _searchDebounce;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _storeService = widget.service ?? StoreService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initStoreAndLoad());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initStoreAndLoad() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (storeProvider.stores.isEmpty) {
      await storeProvider.loadStores();
    }
    if (!mounted) return;

    final preferredId = authProvider.currentUser?.preferredStoreId;
    final availableIds = storeProvider.stores.map((s) => s.id).toList();

    setState(() {
      if (preferredId != null && availableIds.contains(preferredId)) {
        _selectedStoreId = preferredId;
      } else if (availableIds.isNotEmpty) {
        _selectedStoreId = availableIds.first;
      }
    });

    if (_selectedStoreId != null) {
      await _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    if (_selectedStoreId == null) return;
    final generation = ++_requestGeneration;
    final storeId = _selectedStoreId!;
    final search = _searchQuery;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _storeService.getAllStoreProducts(
        storeId,
        search: search,
      );
      if (!mounted || generation != _requestGeneration) return;
      final stores = context.read<StoreProvider>().stores;
      final store = stores.where((s) => s.id == storeId).firstOrNull;
      // Legacy shop rows without explicit currency are PLN. A GB viewer must
      // never turn them into GBP by merely changing the currency symbol.
      if (store == null ||
          list.any(
            (row) =>
                row.storeId != storeId ||
                row.currencyCode != store.currencyCode ||
                !const {'PLN', 'GBP'}.contains(row.currencyCode) ||
                (row.isGenericFood
                    ? !row.hasValidGenericReference
                    : row.price == null ||
                        !row.price!.isFinite ||
                        row.price! < 0 ||
                        (row.currencyCode == 'GBP' &&
                            (row.price == 0 || !row.hasRegionalPackage))),
          )) {
        setState(() {
          _products = [];
          _error = context.strings.productsMarketUnavailable;
        });
        return;
      }
      setState(() {
        _products = list;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = context.strings.productsLoadFailed(e.toString());
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: TextField(
            onChanged: (value) {
              _searchQuery = value;
              _searchDebounce?.cancel();
              _searchDebounce = Timer(
                const Duration(milliseconds: 350),
                _loadProducts,
              );
            },
            decoration: InputDecoration(
              hintText: context.strings.productsSearch,
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              fillColor: AppTheme.surfaceColor.withOpacity(0.5),
            ),
          ),
        ),
        // Wybór sklepu
        if (storeProvider.stores.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                value: _selectedStoreId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.strings.productsShopTab,
                  prefixIcon: const Icon(Icons.storefront_outlined),
                ),
                dropdownColor: AppTheme.surfaceColor,
                items:
                    storeProvider.stores
                        .map(
                          (Store s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  setState(() {
                    _selectedStoreId = value;
                  });
                  _loadProducts();
                },
              ),
            ),
          ),

        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_selectedStoreId == null) {
      return _buildMessageState(
        icon: Icons.storefront_outlined,
        title: context.strings.productsNoShop,
        subtitle: context.strings.productsChooseShop,
      );
    }

    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildMessageState(
        icon: Icons.error_outline,
        title: context.strings.productsError,
        subtitle: _error!,
        action: ElevatedButton(
          onPressed: _loadProducts,
          child: Text(context.strings.productsRetry),
        ),
      );
    }

    if (_products.isEmpty) {
      return _buildMessageState(
        icon: Icons.search_off,
        title: context.strings.productsEmpty,
        subtitle: context.strings.productsChangeSearch,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _products.length,
        itemBuilder: (context, index) => _buildProductTile(_products[index]),
      ),
    );
  }

  Widget _buildProductTile(StoreProduct sp) {
    final product = sp.product;
    final regional = sp.currencyCode == 'GBP';
    final generic = sp.isGenericFood;
    // The canonical food's nutrition is not label evidence for a retailer SKU.
    final kcal =
        regional && !generic
            ? null
            : product?.nutritionPer100.knownValue('kcal');
    final english = context.strings.localeName.startsWith('en');
    final verifiedLabel =
        generic
            ? context.strings.productsGenericFood
            : regional && sp.priceIsEstimated
            ? context.strings.productsEstimatedPrice
            : !english
            ? storePriceVerificationLabel(sp)
            : sp.lastVerified == null
            ? context.strings.productsEstimatedPrice
            : context.strings.productsCheckedOn(
              '${sp.lastVerified!.day.toString().padLeft(2, '0')}/${sp.lastVerified!.month.toString().padLeft(2, '0')}/${sp.lastVerified!.year}',
            );
    final quantityLabel =
        generic
            ? sp.priceQuantity != null
                ? '/ ${formatQuantity(sp.priceQuantity!, sp.priceUnit!)} ${sp.priceUnit!}'
                : ''
            : regional && sp.hasRegionalPackage
            ? '/ ${formatQuantity(sp.packageQuantity!, sp.packageUnit!)} ${sp.packageUnit!}'
            : !english
            ? storePriceQuantityLabel(product)
            : product == null ||
                !product.defaultQuantity.isFinite ||
                product.defaultQuantity <= 0 ||
                product.unit.trim().isEmpty
            ? context.strings.productsUnknownQuantity
            : '/ ${formatQuantity(product.defaultQuantity, product.unit)} ${context.strings.measureQuantityLabel(product.unit, fallback: product.unit, amount: product.defaultQuantity)}';
    final stackedPrice =
        generic &&
        (MediaQuery.sizeOf(context).width < 360 ||
            MediaQuery.textScalerOf(context).scale(14) > 18.2);
    final priceLabel = Column(
      crossAxisAlignment:
          stackedPrice ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          sp.price == null
              ? context.strings.productsPriceUnavailable
              : '${(regional ? sp.priceIsEstimated : sp.lastVerified == null) ? '~ ' : ''}'
                  '${formatMarketMoney(sp.price!, currencyCode: sp.currencyCode)}',
          textAlign: stackedPrice ? TextAlign.start : TextAlign.end,
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        if (quantityLabel.isNotEmpty)
          Text(
            quantityLabel,
            textAlign: stackedPrice ? TextAlign.start : TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
          ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color:
              sp.isAvailable != false
                  ? Colors.transparent
                  : AppTheme.errorColor.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(
              Icons.shopping_basket_outlined,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (regional ? sp.nameEn : product?.displayName(context)) ??
                      context.strings.productsUnknown,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 15),
                  maxLines: generic ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (!generic && sp.storeBrandName != null)
                      context.strings.productsShopBrand(sp.storeBrandName!)
                    else if (!generic && product?.brand != null)
                      context.strings.productsBrand(product!.brand!),
                    if (kcal != null)
                      '${kcal.toInt()} kcal / 100${product?.unit == 'ml' || product?.unit == 'l' ? 'ml' : 'g'}',
                    verifiedLabel,
                    if (generic && sp.price != null)
                      context.strings.productsNationalAverage,
                    if (regional && !generic)
                      context.strings.productsOnlineCatalogue,
                    if (sp.isAvailable == false)
                      context.strings.productsUnavailable,
                  ].join(' • '),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (stackedPrice) ...[const SizedBox(height: 6), priceLabel],
              ],
            ),
          ),
          if (!stackedPrice) ...[
            const SizedBox(width: 8),
            SizedBox(width: 96, child: priceLabel),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 150.ms);
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return _ScrollableProductMessage(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action],
          ],
        ),
      ),
    );
  }
}

/// Zakładka „Moje” — produkty zgłoszone przez zalogowanego użytkownika,
/// niezależnie od tego, czy zostały już zatwierdzone.
class _MyProductsTab extends StatefulWidget {
  final ApiClient? client;
  const _MyProductsTab({super.key, this.client});

  @override
  State<_MyProductsTab> createState() => _MyProductsTabState();
}

class _MyProductsTabState extends State<_MyProductsTab> {
  late final ApiClient _client;
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ApiClient();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _client.get('/products/mine');
      if (!mounted) return;
      setState(() {
        _products =
            (response as List)
                .map((e) => Product.fromJson(e as Map<String, dynamic>))
                .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e, strings: context.strings));
    } finally {
      // finally, żeby kółko zniknęło niezależnie od wyniku żądania —
      // ten sam wzorzec, którego brakowało w panelu admina zanim go
      // naprawiliśmy.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openSubmitSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SubmitProductSheet(),
    );
    if (added == true) _load();
  }

  Future<void> _editProduct(Product p) async {
    final edited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SubmitProductSheet(editing: p),
    );
    if (edited == true) _load();
  }

  Future<void> _deleteProduct(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(context.strings.productsDeleteTitle),
            content: Text(
              context.strings.productsDeleteMessage(p.displayName(context)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.strings.productsCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  context.strings.productsDelete,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _client.delete('/products/${p.id}');
      _load();
    } catch (e) {
      messenger
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSubmitSheet,
        icon: const Icon(Icons.add),
        label: Text(context.strings.productsAdd),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ScrollableProductMessage(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 56,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: Text(context.strings.productsRetry),
                      ),
                    ],
                  ),
                ),
              )
              : _products.isEmpty
              ? _ScrollableProductMessage(
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
                        context.strings.productsNothingSubmitted,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.strings.productsSubmitHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: _products.length,
                  itemBuilder: (context, index) => _buildTile(_products[index]),
                ),
              ),
    );
  }

  Widget _buildTile(Product p) {
    final (label, color) = switch (p.reviewStatus) {
      'approved' => (context.strings.productsApproved, AppTheme.primaryColor),
      'rejected' => (context.strings.productsRejected, AppTheme.errorColor),
      _ => (context.strings.productsPending, AppTheme.textSecondary),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.displayName(context),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (p.brand != null && p.brand!.isNotEmpty) p.brand!,
                    if (p.submittedPrice != null &&
                        p.submittedPrice!.isFinite &&
                        const {'PL', 'GB'}.contains(p.submittedCountryCode))
                      formatMarketMoney(
                        p.submittedPrice!,
                        currencyCode: currencyForAccountCountry(
                          p.submittedCountryCode,
                        ),
                      ),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Edycja i usuwanie — TYLKO tutaj (zakładka "Moje"), bo tu
          // wypisane są WYŁĄCZNIE własne zgłoszenia użytkownika.
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: context.strings.productsEdit,
                visualDensity: VisualDensity.compact,
                onPressed: () => _editProduct(p),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppTheme.errorColor,
                ),
                tooltip: context.strings.productsDelete,
                visualDensity: VisualDensity.compact,
                onPressed: () => _deleteProduct(p),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Error/empty content keeps its centred appearance, but remains reachable
/// when the header, keyboard or larger text leaves little vertical space.
class _ScrollableProductMessage extends StatelessWidget {
  final Widget child;
  const _ScrollableProductMessage({required this.child});
  @override
  Widget build(BuildContext context) =>
      Center(child: SingleChildScrollView(primary: false, child: child));
}
