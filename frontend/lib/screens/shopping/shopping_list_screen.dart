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
import '../../services/shopping_list_service.dart';
import '../../utils/error_utils.dart';
import '../../config/api_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/add_product_sheet.dart';
import '../../widgets/decorative_circles.dart';
import 'price_compare_screen.dart';
import 'export_list_screen.dart';
import 'pending_shares_screen.dart';

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
    // NAPRAWA: wcześniej całe ładowanie list było owinięte w
    // `if (activePlan != null)`. Miało to sens, gdy pobieraliśmy JEDNĄ
    // listę powiązaną z aktywnym planem — bez planu nie było czego
    // pobierać. Ale odkąd ładujemy WSZYSTKIE listy użytkownika, ten
    // warunek stał się błędem: użytkownik bez aktywnego planu (albo taki,
    // któremu plan wygasł) nie dostawał ŻADNEJ listy, mimo że miał ich
    // kilka w bazie — a pasek przełączania nie miał się z czego pokazać.
    //
    // Teraz plan jest tylko PODPOWIEDZIĄ, którą listę wybrać na start
    // (loadAllLists sam spada na pierwszą dostępną, jeśli podpowiedź nie
    // pasuje do żadnej listy albo jest pusta).
    shoppingListProvider.loadAllLists(preferredListId: activePlan?.id);

    // Wcześniej ta funkcja "czy jest promocja na produkt X w sklepie Y" nie
    // istniała wcale (patrz naprawa modułu promocji) — teraz ładujemy
    // aktywne promocje dla wybranego sklepu, żeby pokazać odznaki przy
    // pozycjach listy zakupów.
    promotionProvider.ensureLoadedForStore(storeProvider.selectedStore?.name);
  }

  /// Prosty dialog do udostępnienia listy zakupów innemu użytkownikowi
  /// po adresie e-mail — druga strona musi to zaakceptować, zanim
  /// dostanie faktyczny dostęp (patrz backend, ShoppingListShare).
  Future<void> _showShareDialog(String listId) async {
    final controller = TextEditingController();
    // Udostępniamy po NAZWIE UŻYTKOWNIKA, nie po e-mailu — nazwa jest
    // i tak widoczna publicznie w aplikacji, więc nie trzeba znać ani
    // ujawniać czyjegoś prywatnego adresu. Nazwy są unikalne (pilnuje
    // tego walidacja przy rejestracji i zmianie nicku), więc wskazanie
    // jest jednoznaczne.
    final nickname = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Udostępnij listę zakupów'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Podaj nazwę użytkownika osoby, której chcesz udostępnić listę. '
              'Musi ona mieć konto w Meal Planner Polska i zaakceptować '
              'zaproszenie, zanim zobaczy listę.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Nazwa użytkownika',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Wyślij zaproszenie'),
          ),
        ],
      ),
    );

    if (nickname == null || nickname.isEmpty || !mounted) return;

    try {
      await ShoppingListService().shareList(listId, nickname);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Wysłano zaproszenie do $nickname')),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    }
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
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Zaproszenia do list zakupów',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PendingSharesScreen()),
              );
            },
          ),
          if (list != null)
            IconButton(
              icon: const Icon(Icons.add_shopping_cart),
              tooltip: 'Dodaj produkt',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppTheme.surfaceColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const AddProductSheet(),
              ),
            ),
          if (list != null)
            IconButton(
              icon: const Icon(Icons.person_add_alt_outlined),
              tooltip: 'Udostępnij listę',
              onPressed: () => _showShareDialog(list.id),
            ),
          if (list != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Usuń tę listę',
              onPressed: () {
                final idx = shoppingListProvider.allLists
                    .indexWhere((l) => l.mealPlanId == shoppingListProvider.selectedListId);
                _confirmDeleteList(shoppingListProvider, list, idx >= 0 ? idx + 1 : 1);
              },
            ),
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
                    // 0. Przełącznik listy — widoczny tylko gdy użytkownik
                    // ma więcej niż jedną (Premium może mieć do 5).
                    if (shoppingListProvider.allLists.length > 1)
                      _buildListSelector(shoppingListProvider),

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

  /// Poziomy pasek kart z listami — pozwala przełączyć widoczną listę,
  /// gdy użytkownik ma ich kilka. Etykieta to "Lista N · nazwa sklepu",
  /// bo sama nazwa sklepu nie wystarcza (można mieć dwie listy z tego
  /// samego sklepu), a sam numer nic nie mówi.
  Widget _buildListSelector(ShoppingListProvider provider) {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: provider.allLists.length,
        itemBuilder: (context, index) {
          final l = provider.allLists[index];
          // UWAGA: backend indeksuje listy po ID PLANU POSIŁKÓW, nie po
          // ShoppingList.id (patrz _get_shopping_list_or_404 w
          // backend/app/api/v1/shopping_lists.py) — stąd mealPlanId.
          final isSelected = l.mealPlanId == provider.selectedListId;
          final allItems = l.itemsByDepartment.values.expand((x) => x).toList();
          final checked = allItems.where((i) => i.isChecked).length;
          final total = allItems.length;
          final done = total > 0 && checked == total;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => provider.selectList(l.mealPlanId),
                onLongPress: () => _confirmDeleteList(provider, l, index + 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary.withOpacity(0.25),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lista ${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white.withOpacity(0.85)
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l.storeName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            done ? Icons.check_circle : Icons.shopping_basket_outlined,
                            size: 13,
                            color: isSelected
                                ? Colors.white.withOpacity(0.9)
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$checked/$total',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.9)
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Usunięcie listy zakupów. Wywoływane przytrzymaniem karty listy
  /// oraz z menu w pasku górnym — usuwanie jest nieodwracalne, więc
  /// wymaga potwierdzenia.
  Future<void> _confirmDeleteList(
    ShoppingListProvider provider,
    ShoppingList list,
    int number,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Usunąć listę $number?'),
        content: Text(
          'Lista zakupów dla sklepu ${list.storeName} zostanie trwale '
          'usunięta wraz ze wszystkimi pozycjami. Plan posiłków pozostaje '
          'bez zmian — listę można wygenerować ponownie.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await provider.deleteList(list.mealPlanId);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? 'Lista usunięta' : 'Nie udało się usunąć listy'),
          backgroundColor: ok ? null : AppTheme.errorColor,
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
