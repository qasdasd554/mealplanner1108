import 'package:flutter/material.dart';

import '../l10n/market_locale.dart';
import '../services/price_compare_service.dart';
import '../utils/market_money.dart';
import '../utils/quantity_formatter.dart';

/// Zachowuje zwykłą kartę porównania, lecz rozróżnia pełny koszyk,
/// brakujące ceny i szacunki. Niska cena niepełnego koszyka nie wygrywa.
class StorePriceComparisonCard extends StatelessWidget {
  final PriceComparisonResult result;
  final bool isSwitchingStore;
  final VoidCallback? onSwitchStore;
  final String? switchStoreLabel;
  final bool allowUnpricedListSwitch;

  const StorePriceComparisonCard({
    super.key,
    required this.result,
    this.isSwitchingStore = false,
    this.onSwitchStore,
    this.switchStoreLabel,
    this.allowUnpricedListSwitch = false,
  });

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final total = result.totalPrice;
    final isCheapest = total != null && result.isComplete && result.isCheapest;
    final cardColor = Theme.of(context).colorScheme.primaryContainer;
    // Approved contrast-only repair: preserve the card, shape and background.
    // Some themes use the same green for on-primary actions and the card.
    final actionColor =
        cardColor.computeLuminance() >= 0.179 ? Colors.black : Colors.white;
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final subtitle =
        !result.isComplete
            ? (result.missingProducts.isEmpty
                ? strings.priceCompareUnpricedTotal
                : strings.priceCompareIncomplete(result.missingProducts.length))
            : [
              strings.priceCompareProductCount(result.items.length),
              if (result.hasEstimatedPrices)
                strings.priceCompareEstimatedPrices,
              if (result.savingsVsMostExpensive > 0)
                strings.priceCompareSavings(
                  formatMarketMoney(
                    result.savingsVsMostExpensive,
                    currencyCode: result.currencyCode,
                  ),
                ),
              strings.priceCompareExpandHint,
            ].join(' • ');
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
                  total == null
                      ? strings.priceCompareUnpricedTotal
                      : '${result.hasEstimatedPrices ? '~ ' : ''}'
                          '${formatMarketMoney(total, currencyCode: result.currencyCode)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isCheapest)
                  Text(
                    result.hasEstimatedPrices
                        ? strings.priceCompareCheapestEstimate
                        : strings.priceCompareCheapest,
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
            subtitle,
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ),
        children: [
          const Divider(height: 1),
          if (!result.isComplete)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                result.missingProducts.isEmpty
                    ? strings.priceCompareEmpty
                    : total == null
                    ? strings.priceCompareMissingUnpriced(
                      result.missingProducts.join(', '),
                    )
                    : strings.priceCompareMissing(
                      result.missingProducts.join(', '),
                    ),
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
                '${_unitLabel(context, item.unit)}'
                ' • ${_verificationLabel(context, item)}'
                '${_packageDescription(context, item)}',
                style: TextStyle(fontSize: 12, color: textColor),
              ),
              trailing: SizedBox(
                width: 84,
                child: Text(
                  '${item.priceIsEstimated ? '~ ' : ''}'
                  '${formatMarketMoney(item.priceInStore, currencyCode: result.currencyCode)}',
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
          if ((result.isComplete && total != null) || allowUnpricedListSwitch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style:
                      isCheapest
                          ? OutlinedButton.styleFrom(
                            foregroundColor: actionColor,
                            side: BorderSide(
                              color: actionColor,
                              width:
                                  Theme.of(context)
                                      .outlinedButtonTheme
                                      .style
                                      ?.side
                                      ?.resolve({})
                                      ?.width ??
                                  1,
                            ),
                          )
                          : null,
                  onPressed: isSwitchingStore ? null : onSwitchStore,
                  child:
                      isSwitchingStore
                          ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isCheapest ? actionColor : null,
                            ),
                          )
                          : Text(
                            switchStoreLabel ?? strings.priceCompareSwitchStore,
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

  String _packageDescription(BuildContext context, PriceCompareItem item) {
    final count = item.packageCount;
    final quantity = item.packageQuantity;
    final unit = item.packageUnit;
    if (count == null ||
        count <= 0 ||
        quantity == null ||
        !quantity.isFinite ||
        quantity <= 0 ||
        (unit != 'g' && unit != 'ml')) {
      return '';
    }
    return '\n${context.strings.priceComparePackages(count, formatQuantity(quantity, unit!), unit)}';
  }

  String _unitLabel(BuildContext context, String unit) {
    final strings = context.strings;
    return switch (unit) {
      'opak' => strings.priceCompareUnitPack,
      'porcja' => strings.priceCompareUnitServing,
      'szt' => strings.priceCompareUnitPiece,
      'lyzeczka' => strings.priceCompareUnitTeaspoon,
      'szklanka' => strings.priceCompareUnitCup,
      _ => unit,
    };
  }

  String _verificationLabel(BuildContext context, PriceCompareItem item) {
    final strings = context.strings;
    if (item.isFromPantry) return strings.shoppingInPantry;
    final verified = item.lastVerified;
    if (item.priceIsEstimated || verified == null) {
      return strings.priceCompareEstimate;
    }
    // Keep the established Polish presentation; only UK display is translated.
    final separator = strings.localeName.startsWith('en') ? '/' : '.';
    final date =
        '${verified.day.toString().padLeft(2, '0')}$separator'
        '${verified.month.toString().padLeft(2, '0')}$separator${verified.year}';
    return strings.priceCompareVerified(date);
  }
}
