import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../providers/shopping_list_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../models/shopping_list.dart';
import '../../models/product.dart';
import '../../services/api_client.dart';
import '../../config/api_config.dart';
import '../../theme/app_theme.dart';
import 'price_compare_screen.dart';
import 'export_list_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  final bool isTab;
  const ShoppingListScreen({super.key, this.isTab = false});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _substitutes = [];
  bool _isLoadingSubstitutes = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final mealPlanProvider = Provider.of<MealPlanProvider>(context, listen: false);
    final shoppingListProvider = Provider.of<ShoppingListProvider>(context, listen: false);

    final activePlan = mealPlanProvider.activePlan;
    if (activePlan != null) {
      // Pobierz listę zakupów powiązaną z aktywnym planem
      // Na backendzie relacja 1:1, więc id listy zakupów odpowiada id planu lub pobieramy przez api.
      // Domyślnie na serwerze możemy pobrać listę zakupów bezpośrednio, przekażemy id planu lub pobierzemy najnowszą
      shoppingListProvider.loadShoppingList(activePlan.id);
    }
  }

  // Mapowanie emoji do kategorii/działów
  String _getDeptEmoji(String deptName) {
    return switch (deptName.toLowerCase()) {
      'warzywa i owoce' || 'warzywa' || 'owoce' => '',
      'pieczywo' => '',
      'mięso i wędliny' || 'mięso' => '',
      'ryby' => '',
      'nabiał' => '',
      'produkty suche' || 'suche' => '',
      'mrożonki' => '',
      'przyprawy i sosy' || 'przyprawy' => '',
      _ => '',
    };
  }

  // Pokazuje panel dolny z zamiennikami dla danego produktu
  void _openSubstitutePicker(ShoppingListItem item, String storeId) async {
    setState(() {
      _isLoadingSubstitutes = true;
      _substitutes = [];
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (_isLoadingSubstitutes) {
              if (item.productId == null) {
                Future.microtask(() {
                  if (mounted) {
                    setModalState(() {
                      _isLoadingSubstitutes = false;
                      _substitutes = [];
                    });
                  }
                });
              } else {
                Future.microtask(() async {
                  try {
                    final response = await _apiClient.get(
                        '${ApiConfig.products}${item.productId}/substitutes?store_id=$storeId');
                    if (mounted) {
                      setModalState(() {
                        _substitutes = response as List<dynamic>;
                        _isLoadingSubstitutes = false;
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      setModalState(() {
                        _isLoadingSubstitutes = false;
                        _substitutes = [];
                      });
                    }
                  }
                });
              }

              return const SizedBox(
                height: 250,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wybierz zamiennik',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dla produktu: ${item.productName}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _substitutes.length,
                      itemBuilder: (context, index) {
                        final sub = _substitutes[index];
                        return ListTile(
                          title: Text(sub['name'] as String),
                          subtitle: Text('${sub['brand'] as String? ??''}${sub['kcal'] != null ?' (${sub['kcal']} kcal)':''}'),
                          trailing: Text(
                            '${((sub['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)} zł',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () async {
                            final provider = Provider.of<ShoppingListProvider>(this.context, listen: false);
                            await provider.substituteItem(item.id, sub['id'] as String);
                            if (mounted) {
                              Navigator.of(this.context).pop();
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Zamieniono na: ${sub['name']}'),
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shoppingListProvider = Provider.of<ShoppingListProvider>(context);
    final list = shoppingListProvider.currentList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista zakupów'),
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: shoppingListProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : list == null
              ? _buildEmptyState()
              : Column(
                  children: [
                    // 1. Panel podsumowania (Postęp i cena)
                    _buildSummaryCard(list),

                    // 1b. Akcje: Porównaj ceny i Eksportuj
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.store, size: 18),
                              label: const Text('Porównaj', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                foregroundColor: AppTheme.primaryColor,
                                elevation: 0,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => PriceCompareScreen(mealPlanId: list.mealPlanId),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.ios_share, size: 18),
                              label: const Text('Eksportuj', style: TextStyle(fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                                foregroundColor: AppTheme.accentColor,
                                elevation: 0,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => ExportListDialog(shoppingList: list),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Grupy produktów wg działów
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: list.itemsByDepartment.length,
                        itemBuilder: (context, index) {
                          final deptName = list.itemsByDepartment.keys.elementAt(index);
                          final items = list.itemsByDepartment[deptName]!;
                          final emoji = _getDeptEmoji(deptName);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: const BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              shape: const Border(),
                              leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                              title: Text(
                                deptName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              subtitle: Text(
                                '${items.where((i) => i.isChecked).length} z ${items.length} kupione',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              children: items.map((item) {
                                return _buildShoppingItemTile(item, shoppingListProvider, list.storeId);
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard(ShoppingList list) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        children: [
          // Kołowy wskaźnik postępu (PercentIndicator)
          CircularPercentIndicator(
            radius: 45.0,
            lineWidth: 8.0,
            percent: list.progress,
            center: Text(
              '${(list.progress * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            progressColor: AppTheme.primaryColor,
            backgroundColor: AppTheme.backgroundColor,
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.storeName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${list.checkedItems} z ${list.totalItems} produktów',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Suma: ~${list.totalEstimatedPrice.toStringAsFixed(2)} zł',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingItemTile(
    ShoppingListItem item,
    ShoppingListProvider provider,
    String storeId,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Checkbox(
        value: item.isChecked,
        activeColor: AppTheme.primaryColor,
        onChanged: (_) {
          provider.toggleItem(item.id);
        },
      ),
      title: Text(
        item.productName,
        style: TextStyle(
          decoration: item.isChecked ? TextDecoration.lineThrough : null,
          color: item.isChecked ? AppTheme.textSecondary : AppTheme.textPrimary,
          fontWeight: item.isChecked ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Row(
        children: [
          Text('${item.requiredQuantity} ${item.unit}'),
          if (item.brand != null) ...[
            const SizedBox(width: 8),
            Text('• ${item.brand}', style: const TextStyle(color: AppTheme.textSecondary)),
          ],
          if (item.substitutedForName != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: const Text(
                'ZAMIENNIK',
                style: TextStyle(color: AppTheme.accentColor, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.estimatedPrice != null)
            Text(
              '${item.estimatedPrice!.toStringAsFixed(2)} zł',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.swap_horiz, size: 20, color: AppTheme.textSecondary),
            onPressed: () => _openSubstitutePicker(item, storeId),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 24),
            Text(
              'Brak aktywnej listy zakupów',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Zatwierdź swój plan posiłków na ekranie startowym, aby wygenerować listę zakupów.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
