import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/promotion.dart';
import '../../providers/promotion_provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/app_theme.dart';

/// Ekran promocji — wcześniej ta funkcja w ogóle nie istniała w aplikacji
/// (model i dane demonstracyjne były w kodzie backendu, ale nic ich nie
/// wystawiało ani nie wyświetlało).
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  String? _selectedStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PromotionProvider>(context, listen: false).loadPromotions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final promotionProvider = Provider.of<PromotionProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);

    final filtered = _selectedStore == null
        ? promotionProvider.promotions
        : promotionProvider.promotions
            .where((p) => p.storeName == _selectedStore)
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Promocje')),
      body: Column(
        children: [
          if (storeProvider.stores.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Wszystkie'),
                      selected: _selectedStore == null,
                      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                      onSelected: (_) => setState(() => _selectedStore = null),
                    ),
                  ),
                  ...storeProvider.stores.map((store) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(store.name),
                          selected: _selectedStore == store.name,
                          selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                          onSelected: (_) => setState(() => _selectedStore = store.name),
                        ),
                      )),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: promotionProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : promotionProvider.error != null
                    ? _buildErrorState(promotionProvider)
                    : filtered.isEmpty
                        ? const _EmptyState()
                        : RefreshIndicator(
                            onRefresh: () => promotionProvider.loadPromotions(),
                            color: AppTheme.primaryColor,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) => _PromotionTile(promo: filtered[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(PromotionProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              provider.error ?? 'Nie udało się załadować promocji.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => provider.loadPromotions(),
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromotionTile extends StatelessWidget {
  final Promotion promo;
  const _PromotionTile({required this.promo});

  IconData get _typeIcon => switch (promo.promoType) {
        'multipack' => Icons.inventory_2_outlined,
        'loyalty_card' => Icons.credit_card,
        'weekend' => Icons.event_outlined,
        'clearance' => Icons.local_fire_department_outlined,
        _ => Icons.sell_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_typeIcon, color: Colors.red, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  promo.storeName,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                if (promo.promoDescription != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    promo.promoDescription!,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
                if (promo.requiresLoyaltyCard) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.credit_card, size: 12, color: AppTheme.accentColor),
                      const SizedBox(width: 4),
                      Text(
                        'Wymaga karty lojalnościowej',
                        style: TextStyle(color: AppTheme.accentColor, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${promo.promoPrice.toStringAsFixed(2)} zł',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
              ),
              Text(
                '${promo.regularPrice.toStringAsFixed(2)} zł',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '-${promo.savingsPercent}%',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Brak aktywnych promocji w tej chwili.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
