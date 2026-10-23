import 'package:flutter/material.dart';

import '../../l10n/market_locale.dart';
import '../../services/moderation_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

/// Przegląd WSZYSTKICH komentarzy w aplikacji z możliwością usunięcia.
///
/// Usuwanie pojedynczego komentarza było możliwe już wcześniej (przycisk
/// kosza przy komentarzu pod przepisem — admin widzi go także przy
/// cudzych), ale wymagało odnalezienia komentarza ręcznie, przepis po
/// przepisie. Ten ekran daje jedno miejsce z wyszukiwarką.
class AdminCommentsScreen extends StatefulWidget {
  const AdminCommentsScreen({super.key, this.service});

  final ModerationService? service;

  @override
  State<AdminCommentsScreen> createState() => _AdminCommentsScreenState();
}

class _AdminCommentsScreenState extends State<AdminCommentsScreen> {
  late final ModerationService _service;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _busyIds = {};
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ModerationService();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _service.getAllComments(
        search: _searchController.text,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _comments = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _error = friendlyError(e, strings: context.strings);
      });
    }
  }

  Future<void> _delete(Map<String, dynamic> comment) async {
    final id = comment['id'] as String;
    if (_busyIds.contains(id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(context.strings.adminCommentsDeleteTitle),
            content: Text(context.strings.adminCommentsDeleteBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.strings.planCancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.strings.productsDelete),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted || _busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      await _service.deleteComment(comment['recipe_id'] as String, id);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c['id'] == id);
        _busyIds.remove(id);
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(context.strings.adminCommentsDeleted),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyIds.remove(id));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.adminCommentsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: context.strings.adminCommentsSearch,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _load,
                ),
              ),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                          TextButton(
                            onPressed: _load,
                            child: Text(context.strings.productsRetry),
                          ),
                        ],
                      ),
                    )
                    : _comments.isEmpty
                    ? Center(
                      child: Text(
                        context.strings.adminCommentsEmpty,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          final id = c['id'] as String;
                          final isBusy = _busyIds.contains(id);
                          final text = c['text'] as String?;
                          final hasPhoto = c['has_photo'] as bool? ?? false;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.strings.adminCommentsRecipe(
                                      '${c['recipe_name']}',
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (text == null || text.isEmpty)
                                        ? (hasPhoto
                                            ? context
                                                .strings
                                                .adminCommentsPhotoOnly
                                            : context
                                                .strings
                                                .adminCommentsEmptyText)
                                        : text,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  if (hasPhoto &&
                                      text != null &&
                                      text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.image,
                                            size: 14,
                                            color: AppTheme.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            context
                                                .strings
                                                .adminCommentsHasPhoto,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${c['author_name']} · ${c['author_email']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isBusy)
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: AppTheme.errorColor,
                                            size: 20,
                                          ),
                                          tooltip:
                                              context
                                                  .strings
                                                  .adminCommentsDelete,
                                          onPressed: () => _delete(c),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
