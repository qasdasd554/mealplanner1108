import 'package:flutter/material.dart';

import '../../services/moderation_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

/// Zarządzanie kontami użytkowników — wyszukiwanie i blokowanie/odblokowanie.
///
/// To blokada CAŁEGO konta (nie może się zalogować ani korzystać z API),
/// w odróżnieniu od "Zablokuj autora" dostępnego zwykłym użytkownikom,
/// które tylko ukrywa cudze treści przed jedną osobą.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ModerationService _service = ModerationService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _onlyBanned = false;
  String? _error;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _service.getUsers(
        search: _searchController.text,
        onlyBanned: _onlyBanned,
      );
      if (!mounted) return;
      setState(() {
        _users = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _confirmBan(Map<String, dynamic> user) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Zablokować ${user['display_name'] ?? user['email']}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Konto straci dostęp do aplikacji natychmiast — również '
              'jeśli jest właśnie zalogowane. Dane nie zostaną usunięte, '
              'blokadę można cofnąć.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Powód (widoczny dla użytkownika)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Zablokuj'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _setBanned(user, true, reason: reasonController.text.trim());
  }

  Future<void> _setBanned(
    Map<String, dynamic> user,
    bool banned, {
    String? reason,
  }) async {
    final id = user['id'] as String;
    setState(() => _busyIds.add(id));
    try {
      if (banned) {
        await _service.banUser(id, reason: (reason?.isEmpty ?? true) ? null : reason);
      } else {
        await _service.unbanUser(id);
      }
      if (!mounted) return;
      setState(() {
        user['is_banned'] = banned;
        user['ban_reason'] = banned ? reason : null;
        _busyIds.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(banned ? 'Konto zablokowane' : 'Konto odblokowane')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Użytkownicy')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Szukaj po e-mailu lub nazwie…',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _load,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Tylko zablokowani'),
                      selected: _onlyBanned,
                      onSelected: (v) {
                        setState(() => _onlyBanned = v);
                        _load();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: TextStyle(color: AppTheme.errorColor)),
                            TextButton(onPressed: _load, child: const Text('Spróbuj ponownie')),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Text(
                              'Brak wyników.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final u = _users[index];
                                final id = u['id'] as String;
                                final isBanned = u['is_banned'] as bool? ?? false;
                                final isAdmin = u['role'] == 'admin';
                                final isBusy = _busyIds.contains(id);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(u['display_name'] as String? ?? 'Bez nazwy'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u['email'] as String? ?? '',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (isBanned && u['ban_reason'] != null)
                                          Text(
                                            'Powód: ${u['ban_reason']}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.errorColor,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: isAdmin
                                        ? const Chip(label: Text('admin'))
                                        : isBusy
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : TextButton(
                                                style: TextButton.styleFrom(
                                                  foregroundColor: isBanned
                                                      ? AppTheme.primaryColor
                                                      : AppTheme.errorColor,
                                                ),
                                                onPressed: () => isBanned
                                                    ? _setBanned(u, false)
                                                    : _confirmBan(u),
                                                child: Text(isBanned ? 'Odblokuj' : 'Zablokuj'),
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
