import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../providers/auth_provider.dart';
import '../providers/store_provider.dart';
import '../services/shopping_list_service.dart';
import '../screens/shopping/dish_shopping_list_screen.dart';
import '../screens/profile/premium_screen.dart';
import '../theme/app_theme.dart';
import 'premium_feature_tag.dart';

/// Przycisk "Lista zakupów na to danie" — funkcja Premium.
///
/// UWAGA (zmiana): wcześniej ten widget CAŁKOWICIE ZNIKAŁ dla kont bez
/// dostępu premium — co oznaczało, że osoby na darmowym koncie nie
/// miały nawet jak się dowiedzieć, że taka funkcja istnieje. Teraz
/// przycisk jest ZAWSZE widoczny, ze złotym znacznikiem "PREMIUM" —
/// dla kont bez dostępu dotknięcie prowadzi do ekranu zakupu
/// subskrypcji zamiast samej funkcji.
class DishShoppingListButton extends StatefulWidget {
  final Recipe recipe;

  const DishShoppingListButton({super.key, required this.recipe});

  @override
  State<DishShoppingListButton> createState() => _DishShoppingListButtonState();
}

class _DishShoppingListButtonState extends State<DishShoppingListButton> {
  final ShoppingListService _service = ShoppingListService();
  bool _isBusy = false;

  Future<void> _create() async {
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
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DishShoppingListScreen(shoppingList: list)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException:', '').trim())),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPremiumAccess = Provider.of<AuthProvider>(context).currentUser?.hasPremiumAccess ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _isBusy
              ? null
              : hasPremiumAccess
                  ? _create
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PremiumScreen()),
                      ),
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
              if (!hasPremiumAccess) ...[
                const SizedBox(width: 8),
                const PremiumFeatureTag(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
