import 'package:flutter/material.dart';
import '../../models/shopping_list.dart';
import '../../theme/app_theme.dart';
import '../../utils/quantity_formatter.dart';

/// Prosty, samodzielny podgląd listy zakupów wygenerowanej na konkretne
/// danie(-a) — bez pełnego planu posiłków. Odbiera już gotowe dane
/// (przekazane po utworzeniu listy), nie odpytuje żadnego providera
/// związanego z "aktywnym planem", żeby nie ryzykować kolizji z
/// istniejącym ekranem listy zakupów powiązanej z planem.
class DishShoppingListScreen extends StatelessWidget {
  final ShoppingList shoppingList;

  const DishShoppingListScreen({super.key, required this.shoppingList});

  @override
  Widget build(BuildContext context) {
    final departments = shoppingList.itemsByDepartment.entries.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Lista zakupów')),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Szacowany koszt: ${shoppingList.totalEstimatedPrice.toStringAsFixed(2)} zł',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: departments.isEmpty
                ? Center(
                    child: Text('Brak pozycji na liście', style: TextStyle(color: AppTheme.textSecondary)),
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
                            padding: const EdgeInsets.only(bottom: 8, top: 12),
                            child: Text(
                              dept.key,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          ...dept.value.map((item) => Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  title: Text(item.productName),
                                  subtitle: Text('${formatQuantity(item.requiredQuantity, item.unit)} ${item.unit}'),
                                  trailing: Text(
                                    '${(item.estimatedPrice ?? 0).toStringAsFixed(2)} zł',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )),
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
