import 'package:flutter/material.dart';

import '../services/price_compare_service.dart';
import '../utils/quantity_formatter.dart';
import '../utils/store_price_labels.dart';

/// Zachowuje zwykłą kartę porównania, lecz rozróżnia pełny koszyk,
/// brakujące ceny i szacunki. Niska cena niepełnego koszyka nie wygrywa.
class StorePriceComparisonCard extends StatelessWidget {
  final PriceComparisonResult result;
  final bool isSwitchingStore;
  final VoidCallback? onSwitchStore;

  const StorePriceComparisonCard({
    super.key,
    required this.result,
    this.isSwitchingStore = false,
    this.onSwitchStore,
  });

  @override
  Widget build(BuildContext context) {
    final isCheapest = result.isComplete && result.isCheapest;
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      elevation: isCheapest ? 4 : 1,
      color: isCheapest ? Theme.of(context).colorScheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.storeName,
              style: TextStyle(
                fontWeight: isCheapest ? FontWeight.bold : FontWeight.normal,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${result.hasEstimatedPrices ? '~ ' : ''}'
                  '${result.totalPrice.toStringAsFixed(2)} zł',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isCheapest)
                  Text(
                    result.hasEstimatedPrices
                        ? 'Najniższy szacunek'
                        : 'Najtaniej',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            !result.isComplete
                ? 'Niepełny koszyk • brak cen dla '
                    '${result.missingProducts.length} produktów'
                : '${result.items.length} produktów'
                    '${result.hasEstimatedPrices ? ' • ceny orientacyjne' : ''}'
                    '${result.savingsVsMostExpensive > 0 ? ' • różnica do ${result.savingsVsMostExpensive.toStringAsFixed(2)} zł' : ''}'
                    ' • dotknij, aby zobaczyć listę',
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ),
        children: [
          const Divider(height: 1),
          if (!result.isComplete)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Brak danych cenowych: ${result.missingProducts.join(', ')}. '
                'Pokazana suma dotyczy tylko pozycji z ceną.',
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            ),
          ...result.items.map(
            (item) => ListTile(
              dense: true,
              title: Text(
                item.displayName,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                '${formatQuantity(item.quantityNeeded, item.unit)} '
                '${formatUnitLabel(item.unit)}'
                ' • ${item.priceIsEstimated ? 'cena orientacyjna' : priceVerificationLabel(item.lastVerified)}',
                style: TextStyle(fontSize: 12, color: textColor),
              ),
              trailing: SizedBox(
                width: 84,
                child: Text(
                  '${item.priceIsEstimated ? '~ ' : ''}'
                  '${item.priceInStore.toStringAsFixed(2)} zł',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (result.isComplete)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: isSwitchingStore ? null : onSwitchStore,
                  child:
                      isSwitchingStore
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text(
                            'Przełącz plan na ten sklep',
                            textAlign: TextAlign.center,
                          ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
