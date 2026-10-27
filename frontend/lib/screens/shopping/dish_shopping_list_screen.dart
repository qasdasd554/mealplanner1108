import 'package:flutter/material.dart';
import '../../utils/national_price_reference.dart';
import '../../models/shopping_list.dart';
import '../../theme/app_theme.dart';
import '../../utils/quantity_formatter.dart';
import '../../l10n/catalog_labels.dart';
import '../../l10n/market_locale.dart';
import '../../utils/market_money.dart';

/// Prosty, samodzielny podgląd listy zakupów wygenerowanej na konkretne
/// danie(-a) — bez pełnego planu posiłków. Odbiera już gotowe dane
/// (przekazane po utworzeniu listy), nie odpytuje żadnego providera
/// związanego z "aktywnym planem", żeby nie ryzykować kolizji z
/// istniejącym ekranem listy zakupów powiązanej z planem.
class DishShoppingListScreen extends StatelessWidget {
  final ShoppingList shoppingList;
  final bool friendReadOnly;

  const DishShoppingListScreen({
    super.key,
    required this.shoppingList,
    this.friendReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final departments = shoppingList.itemsByDepartment.entries.toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.shoppingListTitle)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: AppTheme.primaryColor.withOpacity(0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shoppingList.storeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  shoppingList.totalEstimatedPrice == null
                      ? context.strings.shoppingPriceUnknown
                      : context.strings.shoppingEstimatedTotal(
                        formatMarketMoney(
                          shoppingList.totalEstimatedPrice!,
                          currencyCode: shoppingList.currencyCode,
                        ),
                      ),
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                if (friendReadOnly) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.visibility_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(context.strings.shoppingFriendReadOnly),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child:
                departments.isEmpty
                    ? Center(
                      child: Text(
                        context.strings.shoppingNoItems,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: departments.length,
                      itemBuilder: (context, index) {
                        final dept = departments[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 8,
                                top: 12,
                              ),
                              child: Text(
                                dept.value.isNotEmpty &&
                                        dept.value.every(
                                          (item) => item.isFromPantry,
                                        )
                                    ? context.strings.shoppingInPantry
                                    : dept.key == 'Inne'
                                    ? context.strings.shoppingOther
                                    : dept.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ...dept.value.map(
                              (item) => Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  title: Text(item.productName),
                                  subtitle: Text(
                                    '${item.displayQuantity != null && item.displayUnit != null ? '${item.displayQuantityIsApproximate ? '≈' : ''}${formatQuantity(item.displayQuantity!, item.displayUnit!)} ${context.strings.unitLabel(item.displayUnit!)} · ' : ''}${formatQuantity(item.requiredQuantity, item.unit)} ${context.strings.unitLabel(item.unit)}'
                                    '${item.currencyCode == 'GBP' && item.hasReliablePackage ? '\n${context.strings.shoppingPackageBuy(item.packageCount!, formatQuantity(item.packageQuantity!, item.packageUnit!), item.packageUnit!)}' : ''}'
                                    '${item.currencyCode == 'GBP' ? nationalPriceReferenceLabel(item.priceSource, english: context.strings.localeName.startsWith('en'), prefix: '\n') ?? '' : ''}',
                                  ),
                                  trailing: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          item.currencyCode == 'GBP'
                                              ? MediaQuery.sizeOf(
                                                    context,
                                                  ).width *
                                                  0.32
                                              : double.infinity,
                                    ),
                                    child: Text(
                                      item.estimatedPrice == null &&
                                              item.currencyCode == 'GBP'
                                          ? context.strings.shoppingPriceUnknown
                                          : '${item.currencyCode == 'GBP' && item.priceIsEstimated ? '~' : ''}${formatMarketMoney(item.estimatedPrice ?? 0, currencyCode: item.currencyCode)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
