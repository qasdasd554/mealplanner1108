import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../providers/shopping_list_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/promotion_provider.dart';
import '../../models/shopping_list.dart';
import '../../services/api_client.dart';
import '../../services/pantry_service.dart';
import '../../config/api_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decorative_circles.dart';
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
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final promotionProvider = Provider.of<PromotionProvider>(context, listen: false);

    final activePlan = mealPlanProvider.activePlan;
    if (activePlan != null) {
      // Pobierz listę zakupów powiązaną z aktywnym planem
      // Na backendzie relacja 1:1, więc id listy zakupów odpowiada id planu lub pobieramy przez api.
      // Domyślnie na serwerze możemy pobrać listę zakupów bezpośrednio, przekażemy id planu lub pobierzemy najnowszą
      shoppingListProvider.loadShoppingList(activePlan.id);
    }

    // Wcześniej ta funkcja "czy jest promocja na produkt X w sklepie Y" nie
    // istniała wcale (patrz naprawa modułu promocji) — teraz ładujemy
    // aktywne promocje dla wybranego sklepu, żeby pokazać odznaki przy
    // pozycjach listy zakupów.
    promotionProvider.ensureLoadedForStore(storeProvider.selectedStore?.name);
  }

  // Ikony działów (wcześniej tu było mapowanie na emoji — usunięte razem
  // z resztą emotek w aplikacji; funkcja zwracała odtąd puste stringi,
  // czyli renderowała nic zamiast ikony).
  IconData _getDeptIcon(String deptName) {
    return switch (deptName.toLowerCase()) {
      'warzywa i owoce' || 'warzywa' || 'owoce' => Icons.eco_outlined,
      'pieczywo' => Icons.bakery_dining_outlined,
      'mięso i wędliny' || 'mięso' => Icons.set_meal_outlined,
      'ryby' => Icons.set_meal_outlined,
      'nabiał' => Icons.icecream_outlined,
      'produkty suche' || 'suche' => Icons.grain_outlined,
      'mrożonki' => Icons.ac_unit_outlined,
      'przyprawy i sosy' || 'przyprawy' => Icons.local_dining_outlined,
      _ => Icons.shopping_basket_outlined,
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
                    style: TextStyle(color: AppTheme.textSecondary),
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
      body: Stack(
        children: [
          const DecorativeCircles(),
          shoppingListProvider.isLoading
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
                          final deptIcon = _getDeptIcon(deptName);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              shape: const Border(),
                              leading: Icon(deptIcon, color: AppTheme.primaryColor),
                              title: Text(
                                deptName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              subtitle: Text(
                                '${items.where((i) => i.isChecked).length} z ${items.length} kupione',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ShoppingList list) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
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
                  style: TextStyle(color: AppTheme.textSecondary),
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
    // Odznaka promocji — sprawdzana z już wczytanej listy promocji
    // (patrz _loadData), bez dodatkowego zapytania sieciowego na każdą pozycję.
    final promotion = Provider.of<PromotionProvider>(context).findForProduct(item.productName);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Checkbox(
        value: item.isChecked,
        activeColor: AppTheme.primaryColor,
        onChanged: (_) {
          final wasChecked = item.isChecked;
          provider.toggleItem(item.id);
          // Integracja ze Spiżarnią: gdy ZAZNACZAMY pozycję jako kupioną
          // (nie przy odznaczaniu — cofnięcie zakupu nie powinno
          // wyciągać czegoś ze spiżarni, bo mogło już zostać zużyte),
          // produkt trafia też do trwałej listy tego, co mamy w domu.
          // Celowo "w tle" (fire-and-forget) — niepowodzenie tego
          // dodatkowego kroku nie powinno przeszkadzać w głównym
          // przepływie odhaczania zakupów.
          if (!wasChecked && item.productId != null) {
            PantryService().addItems([item.productId!]).catchError((_) {
              // Ciche niepowodzenie — spiżarnia to dodatek, nie krytyczna
              // ścieżka. Użytkownik zawsze może dodać produkt ręcznie
              // później w samej Spiżarni.
              return <PantryItem>[];
            });
          }
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
      subtitle: Wrap(
        // UWAGA (naprawa — przepełnienie "RIGHT OVERFLOWED"): zwykły
        // Row bez żadnej elastyczności przepełniał się, gdy ilość +
        // marka + odznaki (ZAMIENNIK/PROMOCJA) razem nie mieściły się w
        // jednej linii — widoczne dopiero na węższych/innych proporcjach
        // ekranu niż te testowane wcześniej. Wrap automatycznie
        // przenosi elementy do nowej linii zamiast wychodzić poza
        // ekran, z wbudowanymi odstępami (spacing/runSpacing) zamiast
        // ręcznych SizedBox między elementami.
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${item.requiredQuantity} ${item.unit}'),
          if (item.brand != null)
            Text('• ${item.brand}', style: TextStyle(color: AppTheme.textSecondary)),
          if (item.substitutedForName != null)
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
          if (promotion != null)
            Tooltip(
              message: promotion.promoDescription ??
                  '${promotion.regularPrice.toStringAsFixed(2)} zł → '
                      '${promotion.promoPrice.toStringAsFixed(2)} zł',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
                child: Text(
                  'PROMOCJA -${promotion.savingsPercent}%',
                  style: const TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
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
            icon: Icon(Icons.swap_horiz, size: 20, color: AppTheme.textSecondary),
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
            Icon(Icons.shopping_cart_outlined, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 24),
            Text(
              'Brak aktywnej listy zakupów',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
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
