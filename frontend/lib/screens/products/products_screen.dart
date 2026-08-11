import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/store.dart';
import '../../providers/auth_provider.dart';
import '../../providers/store_provider.dart';
import '../../services/store_service.dart';
import '../../theme/app_theme.dart';

/// Ekran przeglądania bazy produktów wybranego sklepu — nazwa, cena,
/// kaloryczność na 100 g/ml. Dostępny z ekranu głównego („Baza produktów”).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final StoreService _storeService = StoreService();

  List<StoreProduct> _products = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initStoreAndLoad());
  }

  Future<void> _initStoreAndLoad() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (storeProvider.stores.isEmpty) {
      await storeProvider.loadStores();
    }

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

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _storeService.getStoreProducts(
        _selectedStoreId!,
        limit: 100,
        search: _searchQuery,
      );
      setState(() {
        _products = list;
      });
    } catch (e) {
      setState(() {
        _error = 'Nie udało się pobrać produktów: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Baza produktów'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _loadProducts();
              },
              decoration: InputDecoration(
                hintText: 'Szukaj produktu...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                fillColor: AppTheme.surfaceColor.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
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
      ),
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
                    if (product?.brand != null) product!.brand!,
                    if (kcal != null) '${kcal.toInt()} kcal / 100${product?.unit == 'ml' || product?.unit == 'l' ? 'ml' : 'g'}',
                    if (!sp.isAvailable) 'niedostępny',
                  ].join(' • '),
                  style: const TextStyle(
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
                '/ ${product?.defaultQuantity ?? 1} ${product?.unit ?? ''}',
                style: const TextStyle(
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
              style: const TextStyle(color: AppTheme.textSecondary),
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
