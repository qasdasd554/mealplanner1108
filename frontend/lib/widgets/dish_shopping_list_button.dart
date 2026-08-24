import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../models/shopping_list.dart';
import '../providers/store_provider.dart';
import '../services/shopping_list_service.dart';
import '../screens/shopping/dish_shopping_list_screen.dart';
import '../screens/profile/premium_screen.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

/// Przycisk "Lista zakupów na to danie".
///
/// UWAGA (zmiana): wcześniej ta funkcja była CAŁKOWICIE zablokowana bez
/// Premium (dotknięcie prowadziło od razu do ekranu zakupu subskrypcji).
/// Teraz dostępna dla WSZYSTKICH — konto standardowe może mieć 1 taką
/// listę, Premium do 5. Po dotknięciu pokazuje wybór: dodaj do już
/// istniejącej listy (jeśli jakąś masz) albo stwórz nową — backend sam
/// pilnuje limitu i zwraca czytelny błąd, jeśli został przekroczony.
class DishShoppingListButton extends StatefulWidget {
  final Recipe recipe;

  const DishShoppingListButton({super.key, required this.recipe});

  @override
  State<DishShoppingListButton> createState() => _DishShoppingListButtonState();
}

class _DishShoppingListButtonState extends State<DishShoppingListButton> {
  final ShoppingListService _service = ShoppingListService();
  bool _isBusy = false;

  Future<void> _onTap() async {
    setState(() => _isBusy = true);
    List<ShoppingList> existingLists = [];
    try {
      existingLists = await _service.getMyLists();
    } catch (_) {
      // Jeśli pobranie listy się nie powiedzie, po prostu pokaż od razu
      // opcję "nowa lista" bez wyboru — nie blokujemy całej funkcji.
    }
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (existingLists.isEmpty) {
      await _createNew();
      return;
    }

    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dodaj do listy zakupów', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Masz już ${existingLists.length} ${existingLists.length == 1 ? "listę" : "listy"} — dodaj do niej, albo stwórz nową.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ...existingLists.map(
                  (list) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.shopping_cart_outlined, color: AppTheme.primaryColor),
                    title: Text(list.storeName),
                    subtitle: Text('${list.itemsByDepartment.values.fold<int>(0, (sum, items) => sum + items.length)} pozycji'),
                    onTap: () => Navigator.of(sheetContext).pop(list.id),
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_circle_outline, color: AppTheme.secondaryColor),
                  title: const Text('Stwórz nową listę'),
                  onTap: () => Navigator.of(sheetContext).pop('__new__'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;
    if (choice == '__new__') {
      await _createNew();
    } else {
      await _addToExisting(choice);
    }
  }

  Future<void> _createNew() => _submit(existingListId: null);
  Future<void> _addToExisting(String listId) => _submit(existingListId: listId);

  Future<void> _submit({required String? existingListId}) async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final store = storeProvider.selectedStore ?? (storeProvider.stores.isNotEmpty ? storeProvider.stores.first : null);
    if (store == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz najpierw sklep w swoim profilu')),
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      final list = await _service.createFromRecipes(
        recipeIds: [widget.recipe.id],
        storeId: store.id,
        existingListId: existingListId,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DishShoppingListScreen(shoppingList: list)),
      );
    } catch (e) {
      if (!mounted) return;
      // UWAGA: limit list (403) to najbardziej prawdopodobny błąd tutaj —
      // dajemy bezpośrednie przejście do Premium zamiast tylko komunikatu,
      // żeby nie trzeba było szukać, jak rozwiązać ten konkretny problem.
      final message = friendlyError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: message.toLowerCase().contains('premium')
              ? SnackBarAction(
                  label: 'Premium',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  ),
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _isBusy ? null : _onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    )
                  : const Icon(Icons.shopping_cart_outlined, size: 18),
              const SizedBox(width: 8),
              const Text('Lista zakupów na to danie'),
            ],
          ),
        ),
      ),
    );
  }
}
