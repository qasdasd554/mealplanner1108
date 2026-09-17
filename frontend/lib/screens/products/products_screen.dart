import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/store.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../services/api_client.dart';
import '../../services/store_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../widgets/submit_product_sheet.dart';
import '../../widgets/price_source_info.dart';

/// Ekran produktów w dwóch zakładkach: „Sklep” (katalog produktów
/// wybranego sklepu, z cenami) i „Moje” (własne zgłoszenia użytkownika,
/// niezależnie od statusu akceptacji).
///
/// NAPRAWA BRAKUJĄCEJ FUNKCJI: zgłoszony produkt zapisywał się w bazie,
/// ale nigdzie w aplikacji nie było miejsca, które by go pokazało —
/// zakładka „Sklep” celowo pokazuje wyłącznie produkty powiązane ze
/// sklepem, a zgłoszenie takiego powiązania nie ma. Druga zakładka
/// domyka tę lukę.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produkty'),
        actions: [
          IconButton(
            tooltip: 'Źródła cen i marek',
            onPressed: () => showPriceSourceInfo(context),
            icon: const Icon(Icons.info_outline),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sklep'),
            Tab(text: 'Moje'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _StoreProductsTab(),
          _MyProductsTab(),
        ],
      ),
    );
  }
}

/// Dawna zawartość ekranu — katalog produktów wybranego sklepu.
class _StoreProductsTab extends StatefulWidget {
  const _StoreProductsTab();

  @override
  State<_StoreProductsTab> createState() => _StoreProductsTabState();
}

class _StoreProductsTabState extends State<_StoreProductsTab> {
  final StoreService _storeService = StoreService();

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
      setState(() {
        _products = list;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = 'Nie udało się pobrać produktów: $e';
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
              hintText: 'Szukaj produktu...',
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
                decoration: const InputDecoration(
                  labelText: 'Sklep',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                dropdownColor: AppTheme.surfaceColor,
                items: storeProvider.stores
                    .map(
                      (Store s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
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

        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_selectedStoreId == null) {
      return _buildMessageState(
        icon: Icons.storefront_outlined,
        title: 'Brak wybranego sklepu',
        subtitle:
            'Aby przeglądać produkty i ceny, wybierz sklep w swoim profilu lub z listy powyżej.',
      );
    }

    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildMessageState(
        icon: Icons.error_outline,
        title: 'Coś poszło nie tak',
        subtitle: _error!,
        action: ElevatedButton(
          onPressed: _loadProducts,
          child: const Text('Spróbuj ponownie'),
        ),
      );
    }

    if (_products.isEmpty) {
      return _buildMessageState(
        icon: Icons.search_off,
        title: 'Brak produktów',
        subtitle: 'Spróbuj zmienić wyszukiwaną frazę.',
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
    final kcal = product?.nutritionPer100.kcal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: sp.isAvailable
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
            child: const Icon(Icons.shopping_basket_outlined,
                color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.name ?? 'Nieznany produkt',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 15,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (sp.storeBrandName != null)
                      'Marka w sklepie: ${sp.storeBrandName}'
                    else if (product?.brand != null)
                      'Marka produktu: ${product!.brand}',
                    if (kcal != null) '${kcal.toInt()} kcal / 100${product?.unit =='ml'|| product?.unit =='l'?'ml':'g'}',
                    if (sp.lastVerified != null) 'cena sprawdzona',
                    if (!sp.isAvailable) 'niedostępny',
                  ].join(' • '),
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${sp.price.toStringAsFixed(2)} zł',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                '/ ${product?.defaultQuantity ?? 1} ${product?.unit ??''}',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
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
    return Center(
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
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// Zakładka „Moje” — produkty zgłoszone przez zalogowanego użytkownika,
/// niezależnie od tego, czy zostały już zatwierdzone.
class _MyProductsTab extends StatefulWidget {
  const _MyProductsTab();

  @override
  State<_MyProductsTab> createState() => _MyProductsTabState();
}

class _MyProductsTabState extends State<_MyProductsTab> {
  final ApiClient _client = ApiClient();
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        _products = (response as List)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
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
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć produkt?'),
        content: Text('Usuniesz "${p.name}" ze swoich zgłoszeń. Tej operacji nie da się cofnąć.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Usuń', style: TextStyle(color: AppTheme.errorColor)),
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
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(friendlyError(e)),
          backgroundColor: AppTheme.errorColor,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSubmitSheet,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj produkt'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 56, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Spróbuj ponownie')),
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
                            Icon(Icons.inventory_2_outlined,
                                size: 56, color: AppTheme.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'Nie zgłosiłeś/aś jeszcze żadnego produktu.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dotknij „Dodaj produkt” poniżej, żeby zgłosić coś,\nczego nie ma w katalogu.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
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
                        itemBuilder: (context, index) =>
                            _buildTile(_products[index]),
                      ),
                    ),
    );
  }

  Widget _buildTile(Product p) {
    final (label, color) = switch (p.reviewStatus) {
      'approved' => ('W katalogu', AppTheme.primaryColor),
      'rejected' => ('Odrzucony', AppTheme.errorColor),
      _ => ('Oczekuje na akceptację', AppTheme.textSecondary),
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
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (p.brand != null && p.brand!.isNotEmpty) p.brand!,
                    if (p.submittedPrice != null)
                      '${p.submittedPrice!.toStringAsFixed(2)} zł',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                        fontSize: 11, color: color, fontWeight: FontWeight.w600),
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
                tooltip: 'Edytuj',
                visualDensity: VisualDensity.compact,
                onPressed: () => _editProduct(p),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
                tooltip: 'Usuń',
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
