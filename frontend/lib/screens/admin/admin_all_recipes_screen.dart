import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../widgets/user_avatar.dart';
import '../recipes/recipe_detail_screen.dart';

/// Panel administratora: wszystkie przepisy dodane przez użytkowników,
/// niezależnie od statusu (prywatny/oczekujący/publiczny/odrzucony),
/// z widoczną nazwą i awatarem autora oraz możliwością usunięcia.
///
/// Celowo pokazuje wszystkie statusy naraz, nie tylko oczekujące na
/// moderację (do tego służy osobny ekran "Przepisy do akceptacji") —
/// tu chodzi o ogólny nadzór: kto co dodał i ewentualne usunięcie
/// nieodpowiedniej treści niezależnie od tego, czy przeszła już
/// moderację, czy nie.
class AdminAllRecipesScreen extends StatefulWidget {
  const AdminAllRecipesScreen({super.key});

  @override
  State<AdminAllRecipesScreen> createState() => _AdminAllRecipesScreenState();
}

class _AdminAllRecipesScreenState extends State<AdminAllRecipesScreen> {
  static const int _pageSize = 30;
  final ApiClient _client = ApiClient();
  List<Map<String, dynamic>> _recipes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = false;
      _error = null;
    });
    try {
      final page = await _fetchPage(0);
      if (!mounted) return;
      setState(() {
        _recipes = page.take(_pageSize).toList();
        _hasMore = page.length > _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recipes = [];
        _error = friendlyError(e);
      });
    } finally {
      // finally, żeby kółko zniknęło niezależnie od wyniku żądania.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPage(int skip) async {
    final response = await _client.get(
      '/recipes/admin/all-user-recipes?skip=$skip&limit=${_pageSize + 1}',
    );
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _fetchPage(_recipes.length);
      if (!mounted) return;
      final existingIds = _recipes.map((recipe) => recipe['id']).toSet();
      final newRecipes =
          page
              .take(_pageSize)
              .where((recipe) => !existingIds.contains(recipe['id']))
              .toList();
      setState(() {
        _recipes.addAll(newRecipes);
        _hasMore = page.length > _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openRecipe(Map<String, dynamic> data) async {
    try {
      final recipe = Recipe.fromJson(data);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const RecipeDetailScreen(),
          settings: RouteSettings(arguments: recipe),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  Future<void> _delete(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Usunąć przepis?'),
            content: Text(
              'Usuniesz "$name" oraz jego komentarze i powiązania (listy zakupów, '
              'plany posiłków innych użytkowników, którzy go używali). Tej operacji '
              'nie da się cofnąć.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anuluj'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Usuń',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    setState(() => _busy.add(id));
    try {
      await _client.delete('/recipes/$id');
      if (!mounted) return;
      setState(() {
        _recipes.removeWhere((r) => r['id'] == id);
        _busy.remove(id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(friendlyError(e)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wszystkie przepisy użytkowników')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Spróbuj ponownie'),
                      ),
                    ],
                  ),
                ),
              )
              : _recipes.isEmpty
              ? Center(
                child: Text(
                  'Brak przepisów dodanych przez użytkowników.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recipes.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _recipes.length) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(0, 6, 0, 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingMore ? null : _loadMore,
                            icon:
                                _isLoadingMore
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.expand_more),
                            label: Text(
                              _isLoadingMore ? 'Ładowanie…' : 'Pokaż więcej',
                            ),
                          ),
                        ),
                      );
                    }

                    final r = _recipes[index];
                    final id = r['id'] as String;
                    final isBusy = _busy.contains(id);
                    final (label, color) = switch (r['visibility']) {
                      'public' => ('Publiczny', AppTheme.primaryColor),
                      'pending' => ('Oczekuje', AppTheme.textSecondary),
                      'rejected' => ('Odrzucony', AppTheme.errorColor),
                      _ => ('Prywatny', AppTheme.textSecondary),
                    };

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: isBusy ? null : () => _openRecipe(r),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserAvatar(
                                  avatar: r['created_by_avatar'] as String?,
                                  avatarPhotoBase64:
                                      r['created_by_avatar_photo'] as String?,
                                  size: 36,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r['name'] as String? ?? '—',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        r['created_by_name'] as String? ??
                                            'Nieznany autor',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: color,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Icon(Icons.chevron_right, size: 20),
                                ),
                                isBusy
                                    ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                    : IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: AppTheme.errorColor,
                                      ),
                                      tooltip: 'Usuń przepis',
                                      onPressed:
                                          () => _delete(
                                            id,
                                            r['name'] as String? ??
                                                'ten przepis',
                                          ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
