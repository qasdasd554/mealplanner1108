import 'package:flutter/material.dart';

import '../../models/friend.dart';
import '../../models/recipe.dart';
import '../../models/shopping_list.dart';
import '../../services/friend_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../l10n/market_locale.dart';
import '../../l10n/recipe_content.dart';
import '../../l10n/catalog_labels.dart';
import '../../widgets/user_avatar.dart';
import '../recipes/recipe_detail_screen.dart';
import '../shopping/dish_shopping_list_screen.dart';

class FriendDetailScreen extends StatefulWidget {
  final FriendEntry friend;
  final FriendService? service;

  const FriendDetailScreen({super.key, required this.friend, this.service});

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  late final FriendService _service;
  List<Recipe>? _recipes;
  List<ShoppingList>? _shoppingLists;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FriendService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final values = await Future.wait([
        _service.getRecipes(widget.friend.userId),
        _service.getShoppingLists(widget.friend.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _recipes = values[0] as List<Recipe>;
        _shoppingLists = values[1] as List<ShoppingList>;
      });
    } catch (error) {
      if (mounted)
        setState(() => _error = friendlyError(error, strings: context.strings));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              UserAvatar(
                avatar: widget.friend.avatar,
                avatarPhotoBase64: widget.friend.avatarPhotoBase64,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.friend.displayName)),
            ],
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: context.strings.recipes),
              Tab(text: context.strings.shoppingListTitle),
            ],
          ),
        ),
        body:
            _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : (_recipes == null || _shoppingLists == null)
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  children: [
                    _RecipeList(recipes: _recipes!),
                    _ShoppingLists(lists: _shoppingLists!),
                  ],
                ),
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  final List<Recipe> recipes;

  const _RecipeList({required this.recipes});

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return _EmptyState(
        icon: Icons.menu_book_outlined,
        text: context.strings.socialNoFriendRecipes,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
              child: const Icon(Icons.restaurant_menu),
            ),
            title: Text(
              recipe.displayName(context),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.strings.socialRecipeSummary(
                recipe.totalTimeMin,
                context.strings.mealTypeLabel(recipe.mealType),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecipeDetailScreen(),
                    settings: RouteSettings(arguments: recipe),
                  ),
                ),
          ),
        );
      },
    );
  }
}

class _ShoppingLists extends StatelessWidget {
  final List<ShoppingList> lists;

  const _ShoppingLists({required this.lists});

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return _EmptyState(
        icon: Icons.shopping_cart_outlined,
        text: context.strings.socialNoFriendLists,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: lists.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final list = lists[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.secondaryColor.withOpacity(0.12),
              child: const Icon(Icons.shopping_basket_outlined),
            ),
            title: Text(
              list.storeName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.strings.shoppingBoughtCount(
                list.checkedItems,
                list.totalItems,
              ),
            ),
            trailing: const Icon(Icons.visibility_outlined),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => DishShoppingListScreen(
                          shoppingList: list,
                          friendReadOnly: true,
                        ),
                  ),
                ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: Text(context.strings.socialRetry),
          ),
        ],
      ),
    ),
  );
}
