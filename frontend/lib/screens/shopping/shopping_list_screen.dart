import 'package:flutter/material.dart';
import '../../utils/national_price_reference.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../providers/shopping_list_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/promotion_provider.dart';
import '../../models/shopping_list.dart';
import '../../l10n/catalog_labels.dart';
import '../../l10n/market_locale.dart';
import '../../services/shopping_list_limit_offer.dart';
import '../../utils/market_money.dart';
import '../../utils/quantity_formatter.dart';
import '../../l10n/measure_labels.dart';
import '../../services/api_client.dart';
import '../../services/shopping_list_service.dart';
import '../../services/price_compare_service.dart';
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
  final ApiClient? apiClient;
  final PriceCompareService? priceCompareService;
  const ShoppingListScreen({
    super.key,
    this.isTab = false,
    this.apiClient,
    this.priceCompareService,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  /// Blokuje przyciski domykania listy na czas żądania.
  bool _isCompleting = false;

  /// Kontroler listy produktów. Panele nad listą mają stałą wysokość, więc
  /// nie przesuwają jej w trakcie gestu.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  late final ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final mealPlanProvider = Provider.of<MealPlanProvider>(
      context,
      listen: false,
    );
    final shoppingListProvider = Provider.of<ShoppingListProvider>(
      context,
      listen: false,
    );
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final promotionProvider = Provider.of<PromotionProvider>(
      context,
      listen: false,
    );

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

  Future<void> _openAddProductSheet() async {
    final shoppingProvider = Provider.of<ShoppingListProvider>(
      context,
      listen: false,
    );

    // Gdy użytkownik nie ma jeszcze listy, plus najpierw tworzy pustą
    // listę dla wybranego sklepu. Dzięki temu przycisk w pustym stanie
    // jest nie tylko widoczny, ale od razu prowadzi do dodania produktu.
    if (shoppingProvider.currentList == null) {
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      if (storeProvider.stores.isEmpty) {
        await storeProvider.loadStores();
      }
      if (!mounted) return;

      if (storeProvider.stores.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                storeProvider.errorMessage ??
                    context.strings.shoppingStoresLoadFailed,
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        return;
      }

      final storeId = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppTheme.surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder:
            (sheetContext) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      context.strings.shoppingChooseStore,
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView(
                      shrinkWrap: true,
                      children:
                          storeProvider.stores
                              .map(
                                (store) => ListTile(
                                  leading: const Icon(Icons.store_outlined),
                                  title: Text(store.name),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap:
                                      () => Navigator.of(
                                        sheetContext,
                                      ).pop(store.id),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
            ),
      );
      if (storeId == null || !mounted) return;

      final created = await shoppingProvider.createEmptyList(storeId);
      if (!mounted) return;
      if (!created) {
        if (await ShoppingListLimitOffer.handle(
          context,
          shoppingProvider.creationFailure,
        ))
          return;
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                shoppingProvider.errorMessage ??
                    context.strings.shoppingCreateFailed,
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        return;
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddProductSheet(),
    );
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
      builder:
          (ctx) => AlertDialog(
            title: Text(context.strings.shoppingShareTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.strings.shoppingShareHint,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.none,
                  decoration: InputDecoration(
                    labelText: context.strings.shoppingUsername,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.strings.aiRecipeCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(context.strings.shoppingSendInvite),
              ),
            ],
          ),
    );

    controller.dispose();
    if (nickname == null || nickname.isEmpty || !mounted) return;

    try {
      await ShoppingListService().shareList(listId, nickname);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(context.strings.shoppingInviteSent(nickname)),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  Future<void> _showMergeDialog(ShoppingListProvider provider) async {
    final current = provider.currentList;
    if (current == null) return;
    final candidates =
        provider.allLists
            .where(
              (list) =>
                  list.mealPlanId != current.mealPlanId &&
                  list.storeId == current.storeId,
            )
            .toList();
    if (candidates.isEmpty) return;
    final selected = <String>{};
    final sourceIds = await showDialog<List<String>>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => AlertDialog(
                  title: Text(context.strings.shoppingMergeTitle),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.strings.shoppingMergeHint(current.storeName),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: candidates.length,
                            itemBuilder: (dialogContext, index) {
                              final list = candidates[index];
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: selected.contains(list.mealPlanId),
                                title: Text(
                                  context.strings.shoppingListNumber(
                                    provider.allLists.indexOf(list) + 1,
                                  ),
                                ),
                                subtitle: Text(
                                  context.strings.shoppingListDate(
                                    list.createdAt.day,
                                    list.createdAt.month,
                                    list.totalItems,
                                  ),
                                ),
                                onChanged:
                                    (checked) => setDialogState(() {
                                      if (checked == true) {
                                        selected.add(list.mealPlanId);
                                      } else {
                                        selected.remove(list.mealPlanId);
                                      }
                                    }),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(context.strings.aiRecipeCancel),
                    ),
                    FilledButton(
                      onPressed:
                          selected.isEmpty
                              ? null
                              : () => Navigator.of(
                                dialogContext,
                              ).pop(selected.toList()),
                      child: Text(context.strings.shoppingMerge),
                    ),
                  ],
                ),
          ),
    );
    if (sourceIds == null || sourceIds.isEmpty || !mounted) return;
    final success = await provider.mergeLists([
      current.mealPlanId,
      ...sourceIds,
    ]);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(
            success
                ? context.strings.shoppingMergeSuccess
                : provider.errorMessage ?? context.strings.shoppingMergeFailed,
          ),
          backgroundColor: success ? null : AppTheme.errorColor,
        ),
      );
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
      'w spiżarni' => Icons.kitchen_outlined,
      _ => Icons.shopping_basket_outlined,
    };
  }

  // The request belongs to this opening, not to a modal builder/rebuild.
  Future<void> _openSubstitutePicker(
    ShoppingListItem item,
    String storeId,
  ) async {
    final strings = context.strings;
    final provider = context.read<ShoppingListProvider>();
    var saving = false;

    Future<({List<dynamic> items, Object? error})> load() async {
      if (item.productId == null) return (items: <dynamic>[], error: null);
      try {
        final response = await _apiClient.get(
          '${ApiConfig.products}${item.productId}/substitutes?store_id=$storeId',
        );
        final items =
            (response as List<dynamic>)
                .where(
                  (sub) =>
                      supportedCurrencyCode(
                        sub['currency_code']?.toString() ?? 'PLN',
                      ) ==
                      item.currencyCode,
                )
                .toList();
        return (items: items, error: null);
      } catch (error) {
        return (items: <dynamic>[], error: error);
      }
    }

    final request = load();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (
                  modalContext,
                  setModalState,
                ) => FutureBuilder<({List<dynamic> items, Object? error})>(
                  future: request,
                  builder: (resultContext, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 250,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final result = snapshot.data!;
                    return Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.shoppingChooseSubstitute,
                            style: Theme.of(resultContext)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.shoppingSubstituteFor(item.productName),
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child:
                                result.error != null
                                    ? Center(
                                      child: Text(
                                        friendlyError(result.error!),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                    : result.items.isEmpty
                                    ? Center(
                                      child: Text(
                                        strings.shoppingNoSubstitutes,
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                    : ListView.builder(
                                      itemCount: result.items.length,
                                      itemBuilder: (rowContext, index) {
                                        final sub = result.items[index];
                                        final catalogue =
                                            sub['availability_scope'] ==
                                            'generic_food_reference';
                                        final showHeading =
                                            index == 0 ||
                                            catalogue !=
                                                (result.items[index -
                                                        1]['availability_scope'] ==
                                                    'generic_food_reference');
                                        final packageQuantity =
                                            (sub['package_quantity'] as num?)
                                                ?.toDouble();
                                        final packageUnit =
                                            sub['package_unit'] as String?;
                                        final hasPackage =
                                            packageQuantity != null &&
                                            packageQuantity.isFinite &&
                                            packageQuantity > 0 &&
                                            const {
                                              'g',
                                              'ml',
                                            }.contains(packageUnit);
                                        final priceQuantity =
                                            (sub['price_quantity'] as num?)
                                                ?.toDouble();
                                        final priceUnit =
                                            sub['price_unit'] as String?;
                                        final quantityReference =
                                            sub['price_basis'] ==
                                                'quantity_reference' &&
                                            priceQuantity != null &&
                                            priceQuantity.isFinite &&
                                            priceQuantity > 0 &&
                                            const {
                                              'g',
                                              'ml',
                                              'szt',
                                            }.contains(priceUnit);
                                        final subtitle =
                                            '${sub['brand'] as String? ?? ''}${sub['kcal'] != null ? ' (${sub['kcal']} kcal)' : ''}';
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (item.currencyCode == 'GBP' &&
                                                showHeading)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                      16,
                                                      12,
                                                      16,
                                                      4,
                                                    ),
                                                child: Text(
                                                  catalogue
                                                      ? strings
                                                          .shoppingCatalogueAlternatives
                                                      : strings
                                                          .shoppingStoreAlternatives,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ListTile(
                                              title: Text(
                                                sub['name'] as String,
                                              ),
                                              subtitle: Text(
                                                item.currencyCode == 'GBP' &&
                                                        hasPackage
                                                    ? [
                                                          subtitle,
                                                          strings
                                                              .shoppingSubstitutePack(
                                                                formatQuantity(
                                                                  packageQuantity,
                                                                  packageUnit!,
                                                                ),
                                                                packageUnit,
                                                              ),
                                                        ]
                                                        .where(
                                                          (value) =>
                                                              value.isNotEmpty,
                                                        )
                                                        .join(' · ')
                                                    : quantityReference
                                                    ? '${catalogue ? '${strings.shoppingCatalogueAvailability}\n' : ''}$subtitle · ${strings.productsEstimatedPrice} / ${formatQuantity(priceQuantity, priceUnit!)} ${strings.measureQuantityLabel(priceUnit, fallback: priceUnit, amount: priceQuantity)}'
                                                    : subtitle,
                                              ),
                                              trailing: Text(
                                                sub['price'] == null &&
                                                        item.currencyCode ==
                                                            'GBP'
                                                    ? strings
                                                        .shoppingPriceUnknown
                                                    : '${item.currencyCode == 'GBP' && (sub['price_is_estimated'] as bool? ?? true) ? '~' : ''}${formatMarketMoney((sub['price'] as num?)?.toDouble() ?? 0.0, currencyCode: item.currencyCode)}',
                                                style: const TextStyle(
                                                  color: AppTheme.primaryColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              onTap:
                                                  saving
                                                      ? null
                                                      : () async {
                                                        if (saving) return;
                                                        final name =
                                                            sub['name']
                                                                as String;
                                                        setModalState(
                                                          () => saving = true,
                                                        );
                                                        try {
                                                          final saved =
                                                              await provider
                                                                  .substituteItem(
                                                                    item.id,
                                                                    sub['id']
                                                                        as String,
                                                                  );
                                                          if (!mounted ||
                                                              !modalContext
                                                                  .mounted) {
                                                            return;
                                                          }
                                                          if (saved) {
                                                            Navigator.of(
                                                              modalContext,
                                                            ).pop();
                                                          } else {
                                                            setModalState(
                                                              () =>
                                                                  saving =
                                                                      false,
                                                            );
                                                          }
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              duration:
                                                                  const Duration(
                                                                    seconds: 3,
                                                                  ),
                                                              content: Text(
                                                                saved
                                                                    ? strings
                                                                        .shoppingSubstituteChanged(
                                                                          name,
                                                                        )
                                                                    : provider
                                                                            .errorMessage ??
                                                                        strings
                                                                            .shoppingSubstituteFailed,
                                                              ),
                                                              backgroundColor:
                                                                  saved
                                                                      ? AppTheme
                                                                          .primaryColor
                                                                      : AppTheme
                                                                          .errorColor,
                                                            ),
                                                          );
                                                        } catch (error) {
                                                          if (!mounted ||
                                                              !modalContext
                                                                  .mounted) {
                                                            return;
                                                          }
                                                          setModalState(
                                                            () =>
                                                                saving = false,
                                                          );
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                friendlyError(
                                                                  error,
                                                                ),
                                                              ),
                                                              backgroundColor:
                                                                  AppTheme
                                                                      .errorColor,
                                                            ),
                                                          );
                                                        }
                                                      },
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shoppingListProvider = Provider.of<ShoppingListProvider>(context);
    final list = shoppingListProvider.currentList;
    final compactBritish = list != null && _isCompactBritish(list.currencyCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.shoppingListTitle),
        leading:
            widget.isTab
                ? null
                : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
      ),
      // Dodawanie produktu jako PŁYWAJĄCY przycisk, a nie ikona w pasku —
      // w pasku ginęła między pozostałymi ikonami i była trudna do
      // zauważenia. Ten sam wzorzec co w zakładce Śledzenie, więc
      // zachowanie jest spójne w całej aplikacji.
      floatingActionButton: FloatingActionButton(
        onPressed: shoppingListProvider.isLoading ? null : _openAddProductSheet,
        backgroundColor: AppTheme.primaryColor,
        tooltip:
            list == null
                ? context.strings.shoppingCreateAndAdd
                : context.strings.shoppingAddProduct,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(
        children: [
          const DecorativeCircles(),
          shoppingListProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : list == null
              ? _buildEmptyState()
              : CustomScrollView(
                controller: _scrollController,
                // Nagłówek i produkty należą do jednego przewijania.
                // Dzięki temu górna część znika dokładnie wraz z gestem,
                // bez odbierania wysokości osobnej, wewnętrznej liście.
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Rząd kafelków akcji — ten sam wzorzec wizualny co
                        // szybkie filtry w zakładce Przepisy (ikona + podpis
                        // w ramce). Wcześniej były to nieopisane ikony w pasku,
                        // po których nie dało się poznać, co robią.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
                          child: Row(
                            children: [
                              _buildActionTile(
                                icon: Icons.mail_outline,
                                label: context.strings.shoppingInvites,
                                onTap:
                                    () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const PendingSharesScreen(),
                                      ),
                                    ),
                              ),
                              _buildActionTile(
                                icon: Icons.person_add_alt_outlined,
                                label: context.strings.shoppingShare,
                                onTap: () => _showShareDialog(list.id),
                              ),
                              _buildActionTile(
                                icon: Icons.refresh,
                                label: context.strings.shoppingRefresh,
                                onTap: _loadData,
                              ),
                              _buildActionTile(
                                icon: Icons.delete_outline,
                                label: context.strings.shoppingDeleteList,
                                color: AppTheme.errorColor,
                                onTap: () {
                                  final idx = shoppingListProvider.allLists
                                      .indexWhere(
                                        (l) =>
                                            l.mealPlanId ==
                                            shoppingListProvider.selectedListId,
                                      );
                                  _confirmDeleteList(
                                    shoppingListProvider,
                                    list,
                                    idx >= 0 ? idx + 1 : 1,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // 0. Przełącznik listy — widoczny tylko gdy użytkownik
                        // ma więcej niż jedną (Premium może mieć do 5).
                        if (shoppingListProvider.allLists.length > 1)
                          _buildListSelector(shoppingListProvider),
                        if (shoppingListProvider.allLists.any(
                          (other) =>
                              other.mealPlanId != list.mealPlanId &&
                              other.storeId == list.storeId,
                        ))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed:
                                    () =>
                                        _showMergeDialog(shoppingListProvider),
                                icon: const Icon(Icons.merge_type, size: 18),
                                label: Text(context.strings.shoppingMergeLists),
                              ),
                            ),
                          ),

                        // Panel domknięcia zakupów — pokazuje się DOPIERO
                        // po odhaczeniu wszystkiego, więc nie zabiera miejsca
                        // w trakcie zakupów, a pojawia się dokładnie w
                        // momencie, gdy jest potrzebny.
                        if (list.isFullyChecked)
                          _buildCompletionPanel(shoppingListProvider, list),

                        // Cały nagłówek przewija się teraz w tym samym sliverze
                        // co produkty, więc znika płynnie bez skoku zawartości.
                        _buildSummaryCard(list),

                        // 1b. Akcje: Porównaj ceny i Eksportuj
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: Flex(
                            direction:
                                compactBritish
                                    ? Axis.vertical
                                    : Axis.horizontal,
                            crossAxisAlignment:
                                compactBritish
                                    ? CrossAxisAlignment.stretch
                                    : CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                flex: compactBritish ? 0 : 1,
                                fit: FlexFit.tight,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.store, size: 18),
                                  label: Text(
                                    context.strings.shoppingCompare,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryTintColor,
                                    foregroundColor:
                                        AppTheme.actionPrimaryColor,
                                    side: BorderSide(
                                      color: AppTheme.actionPrimaryColor
                                          .withOpacity(
                                            AppTheme.isDark ? 0.85 : 0.35,
                                          ),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    final switched = await Navigator.of(
                                      context,
                                    ).push<bool>(
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                PriceCompareScreen.shoppingList(
                                                  shoppingListId:
                                                      list.mealPlanId,
                                                  currencyCode:
                                                      list.currencyCode,
                                                  service:
                                                      widget
                                                          .priceCompareService,
                                                ),
                                      ),
                                    );
                                    if (!context.mounted || switched != true) {
                                      return;
                                    }
                                    await context
                                        .read<ShoppingListProvider>()
                                        .loadAllLists(
                                          preferredListId: list.mealPlanId,
                                        );
                                  },
                                ),
                              ),
                              SizedBox(
                                width: compactBritish ? 0 : 12,
                                height: compactBritish ? 12 : 0,
                              ),
                              Flexible(
                                flex: compactBritish ? 0 : 1,
                                fit: FlexFit.tight,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.ios_share, size: 18),
                                  label: Text(
                                    context.strings.shoppingExport,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentTintColor,
                                    foregroundColor: AppTheme.actionAccentColor,
                                    side: BorderSide(
                                      color: AppTheme.actionAccentColor
                                          .withOpacity(
                                            AppTheme.isDark ? 0.85 : 0.35,
                                          ),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    final accountCountry =
                                        context
                                            .read<AuthProvider?>()
                                            ?.currentUser
                                            ?.countryCode ??
                                        'PL';
                                    showDialog(
                                      context: context,
                                      builder:
                                          (context) => ExportListDialog(
                                            shoppingList: list,
                                            accountCountry: accountCountry,
                                          ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Grupy produktów wg działów. To kontynuacja tego
                  // samego scrolla, a nie druga lista z osobnym offsetem.
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    sliver: SliverList.builder(
                      itemCount: list.itemsByDepartment.length,
                      itemBuilder: (context, index) {
                        final deptName = list.itemsByDepartment.keys.elementAt(
                          index,
                        );
                        final items = list.itemsByDepartment[deptName]!;
                        final deptIcon = _getDeptIcon(deptName);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(20),
                            ),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            shape: const Border(),
                            leading: Icon(
                              deptIcon,
                              color: AppTheme.primaryColor,
                            ),
                            title: Text(
                              items.isNotEmpty &&
                                      items.every((item) => item.isFromPantry)
                                  ? context.strings.shoppingInPantry
                                  : deptName == 'Inne'
                                  ? context.strings.shoppingOther
                                  : deptName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              items.isNotEmpty &&
                                      items.every((item) => item.isFromPantry)
                                  ? context.strings.shoppingPantryCount(
                                    items.length,
                                    list.currencyCode == 'PLN'
                                        ? '0 zł'
                                        : formatMarketMoney(
                                          0,
                                          currencyCode: list.currencyCode,
                                        ),
                                  )
                                  : context.strings.shoppingBoughtCount(
                                    items.where((i) => i.isChecked).length,
                                    items.length,
                                  ),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            children:
                                items.map((item) {
                                  return _buildShoppingItemTile(
                                    item,
                                    shoppingListProvider,
                                    list.storeId,
                                  );
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
  /// Kafelek akcji w stylu szybkich filtrów z zakładki Przepisy.
  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final active = onTap != null;
    final tint = color ?? AppTheme.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tint.withOpacity(active ? 0.35 : 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: tint.withOpacity(active ? 1 : 0.4)),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: tint.withOpacity(active ? 1 : 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListSelector(ShoppingListProvider provider) {
    return SizedBox(
      // Dwie linie opisu listy oraz ikona potrzebują nieco więcej miejsca
      // niż poprzednie 64 px. Na iPhone'ach z większą skalą tekstu dolny
      // wiersz wystawał o 6 px i Flutter rysował czerwony pasek overflow.
      height: 76,
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
          final allItems =
              l.itemsByDepartment.values
                  .expand((x) => x)
                  .where((item) => !item.isFromPantry)
                  .toList();
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary.withOpacity(0.25),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.strings.shoppingListNumber(index + 1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected
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
                              color:
                                  isSelected
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            done
                                ? Icons.check_circle
                                : Icons.shopping_basket_outlined,
                            size: 13,
                            color:
                                isSelected
                                    ? Colors.white.withOpacity(0.9)
                                    : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$checked/$total',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isSelected
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
      builder:
          (dialogContext) => AlertDialog(
            title: Text(context.strings.shoppingDeleteTitle(number)),
            content: Text(context.strings.shoppingDeleteHint(list.storeName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.strings.aiRecipeCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.strings.shoppingDelete),
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
          duration: const Duration(seconds: 3),
          content: Text(
            ok
                ? context.strings.shoppingDeleted
                : context.strings.shoppingDeleteFailed,
          ),
          backgroundColor: ok ? null : AppTheme.errorColor,
        ),
      );
  }

  /// Panel z akcjami domykającymi zakupy, widoczny po odhaczeniu
  /// wszystkich pozycji.
  Widget _buildCompletionPanel(
    ShoppingListProvider provider,
    ShoppingList list,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.strings.shoppingHaveEverything,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.strings.shoppingCompleteHint,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          // Przyciski JEDEN POD DRUGIM na pełną szerokość, nie obok
          // siebie: "Przenieś do spiżarni" i "Tylko zakończ" to długie
          // etykiety, które na wąskim ekranie rozjeżdżały się i nachodziły
          // na siebie. Układ pionowy jest odporny na każdą szerokość.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _isCompleting ? null : () => _completeList(provider, true),
              icon:
                  _isCompleting
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.kitchen, size: 18),
              label: Text(context.strings.shoppingMovePantry),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed:
                  _isCompleting ? null : () => _completeList(provider, false),
              child: Text(context.strings.shoppingCompleteWithoutPantry),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeList(
    ShoppingListProvider provider,
    bool moveToPantry,
  ) async {
    setState(() => _isCompleting = true);
    final moved = await provider.completeList(moveToPantry: moveToPantry);
    if (!mounted) return;
    setState(() => _isCompleting = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            moved == null
                ? (provider.errorMessage ??
                    context.strings.shoppingCompleteFailed)
                : moveToPantry
                ? context.strings.shoppingCompleteMoved(moved)
                : context.strings.shoppingCompleteSuccess,
          ),
          backgroundColor: moved == null ? AppTheme.errorColor : null,
        ),
      );
  }

  bool _isCompactBritish(String currencyCode) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return currencyCode == 'GBP' &&
        MediaQuery.sizeOf(context).width / textScale < 360;
  }

  Widget _buildSummaryCard(ShoppingList list) {
    final amountBelow =
        _isCompactBritish(list.currencyCode) &&
        list.hasUnknownPrices &&
        !list.isFullyChecked;
    final amount = Text(
      list.isFullyChecked
          ? context.strings.shoppingEverythingBought
          : list.hasUnknownPrices
          ? list.currencyCode == 'GBP' && list.remainingPrice == 0
              ? context.strings.shoppingPriceUnknown
              : context.strings.shoppingUnknownRemaining(
                formatMarketMoney(
                  list.remainingPrice,
                  currencyCode: list.currencyCode,
                ),
              )
          : context.strings.shoppingRemaining(
            formatMarketMoney(
              list.remainingPrice,
              currencyCode: list.currencyCode,
            ),
          ),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.bold,
      ),
    );
    final overview = Row(
      children: [
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                context.strings.shoppingProgressCount(
                  list.checkedItems,
                  list.totalItems,
                ),
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              if (!amountBelow) ...[const SizedBox(height: 8), amount],
              if (!list.isFullyChecked &&
                  list.checkedItems > 0 &&
                  list.totalEstimatedPrice != null) ...[
                const SizedBox(height: 2),
                Text(
                  context.strings.shoppingBasketTotal(
                    formatMarketMoney(
                      list.totalEstimatedPrice! - list.remainingPrice,
                      currencyCode: list.currencyCode,
                    ),
                    formatMarketMoney(
                      list.totalEstimatedPrice!,
                      currencyCode: list.currencyCode,
                    ),
                  ),
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child:
          amountBelow
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [overview, const SizedBox(height: 8), amount],
              )
              : overview,
    );
  }

  Widget _buildShoppingItemTile(
    ShoppingListItem item,
    ShoppingListProvider provider,
    String storeId,
  ) {
    final compactBritish = _isCompactBritish(item.currencyCode);
    final referenceLabel =
        item.currencyCode == 'GBP'
            ? nationalPriceReferenceLabel(
              item.priceSource,
              english: context.strings.localeName.startsWith('en'),
            )
            : null;
    final priceLabel =
        item.estimatedPrice == null
            ? null
            : '${item.currencyCode == 'GBP' && item.priceIsEstimated ? '~' : ''}${formatMarketMoney(item.estimatedPrice!, currencyCode: item.currencyCode)}';
    // Odznaka promocji — sprawdzana z już wczytanej listy promocji
    // (patrz _loadData), bez dodatkowego zapytania sieciowego na każdą pozycję.
    final promotion =
        item.isFromPantry || item.currencyCode != 'PLN'
            ? null
            : Provider.of<PromotionProvider>(
              context,
            ).findForProduct(item.productName);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading:
          item.isFromPantry
              ? const Icon(Icons.kitchen_outlined, color: AppTheme.primaryColor)
              : Checkbox(
                value: item.isChecked,
                activeColor: AppTheme.primaryColor,
                onChanged:
                    provider.isTogglePending(item.id)
                        ? null
                        : (_) async {
                          final saved = await provider.toggleItem(item.id);
                          if (!saved && mounted) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.errorMessage ??
                                        context.strings.shoppingItemSaveFailed,
                                  ),
                                ),
                              );
                          }
                        },
              ),
      title: Text(
        item.productName,
        style: TextStyle(
          decoration:
              !item.isFromPantry && item.isChecked
                  ? TextDecoration.lineThrough
                  : null,
          color:
              !item.isFromPantry && item.isChecked
                  ? AppTheme.textSecondary
                  : AppTheme.textPrimary,
          fontWeight:
              !item.isFromPantry && item.isChecked
                  ? FontWeight.normal
                  : FontWeight.bold,
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
          Text(
            item.displayQuantity != null && item.displayUnit != null
                ? '${item.displayQuantityIsApproximate ? '≈' : ''}${formatQuantity(item.displayQuantity!, item.displayUnit!)} ${context.strings.unitLabel(item.displayUnit!)} (${formatQuantity(item.requiredQuantity, item.unit)} ${context.strings.unitLabel(item.unit)})'
                : '${formatQuantity(item.requiredQuantity, item.unit)} ${context.strings.unitLabel(item.unit)}',
          ),
          if (item.currencyCode == 'GBP' && item.hasReliablePackage)
            Text(
              context.strings.shoppingPackageBuy(
                item.packageCount!,
                formatQuantity(item.packageQuantity!, item.packageUnit!),
                item.packageUnit!,
              ),
            ),
          if (referenceLabel != null) Text(referenceLabel),
          if (compactBritish && priceLabel != null)
            Text(
              priceLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (item.brand != null)
            Text(
              '• ${item.brand}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          if (item.substitutedForName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: Text(
                context.strings.shoppingSubstituteBadge,
                style: const TextStyle(
                  color: AppTheme.accentColor,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (promotion != null)
            Tooltip(
              message:
                  promotion.promoDescription ??
                  '${formatMarketMoney(promotion.regularPrice, currencyCode: item.currencyCode)} → '
                      '${formatMarketMoney(promotion.promoPrice, currencyCode: item.currencyCode)}',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
                child: Text(
                  context.strings.shoppingPromotionBadge(
                    promotion.savingsPercent,
                  ),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      trailing:
          compactBritish && (item.productId == null || item.isFromPantry)
              ? null
              : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (priceLabel != null && !compactBritish)
                    Text(
                      priceLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  if (item.productId != null && !item.isFromPantry) ...[
                    if (!compactBritish) const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.swap_horiz,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => _openSubstitutePicker(item, storeId),
                    ),
                  ],
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
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              context.strings.shoppingEmptyTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.strings.shoppingEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            // NAPRAWA: przycisk zaproszeń był WYŁĄCZNIE w widoku z listą,
            // więc użytkownik bez własnej listy nie miał jak przyjąć
            // zaproszenia — dostawał je, ale nie mógł się do niego dostać.
            // A to najczęstsza sytuacja: ktoś udostępnia listę komuś, kto
            // sam żadnej jeszcze nie stworzył.
            OutlinedButton.icon(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PendingSharesScreen(),
                    ),
                  ),
              icon: const Icon(Icons.mail_outline, size: 18),
              label: Text(context.strings.shoppingListInvites),
            ),
          ],
        ),
      ),
    );
  }
}
