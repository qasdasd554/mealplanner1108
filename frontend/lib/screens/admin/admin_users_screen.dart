import 'package:flutter/material.dart';

import '../../l10n/market_locale.dart';
import '../../services/moderation_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';
import '../../widgets/user_avatar.dart';

/// Zarządzanie kontami użytkowników — wyszukiwanie i blokowanie/odblokowanie.
///
/// To blokada CAŁEGO konta (nie może się zalogować ani korzystać z API),
/// w odróżnieniu od "Zablokuj autora" dostępnego zwykłym użytkownikom,
/// które tylko ukrywa cudze treści przed jedną osobą.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, this.service});

  final ModerationService? service;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late final ModerationService _service;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _onlyBanned = false;
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
      final list = await _service.getUsers(
        search: _searchController.text,
        onlyBanned: _onlyBanned,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _users = list;
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

  Future<void> _confirmBan(Map<String, dynamic> user) async {
    if (_busyIds.contains(user['id'])) return;
    var reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(
              context.strings.adminUsersBanTitle(
                '${user['display_name'] ?? user['email']}',
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.strings.adminUsersBanBody,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (value) => reason = value,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: context.strings.adminUsersReasonLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
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
                child: Text(context.strings.adminUsersBan),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;
    await _setBanned(user, true, reason: reason.trim());
  }

  Future<void> _setBanned(
    Map<String, dynamic> user,
    bool banned, {
    String? reason,
  }) async {
    final id = user['id'] as String;
    if (_busyIds.contains(id)) return;
    setState(() => _busyIds.add(id));
    try {
      if (banned) {
        await _service.banUser(
          id,
          reason: (reason?.isEmpty ?? true) ? null : reason,
        );
      } else {
        await _service.unbanUser(id);
      }
      if (!mounted) return;
      setState(() {
        user['is_banned'] = banned;
        user['ban_reason'] = banned ? reason : null;
        _busyIds.remove(id);
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(
              banned
                  ? context.strings.adminUsersBanned
                  : context.strings.adminUsersUnbanned,
            ),
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
      appBar: AppBar(title: Text(context.strings.adminUsersTitle)),
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
                    hintText: context.strings.adminUsersSearch,
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
                    Flexible(
                      child: FilterChip(
                        label: Text(context.strings.adminUsersOnlyBanned),
                        selected: _onlyBanned,
                        onSelected: (v) {
                          setState(() => _onlyBanned = v);
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
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
                    : _users.isEmpty
                    ? Center(
                      child: Text(
                        context.strings.adminUsersEmpty,
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
                              leading: UserAvatar(
                                avatar: u['avatar'] as String?,
                                avatarPhotoBase64:
                                    u['avatar_photo_base64'] as String?,
                                size: 44,
                              ),
                              title: Text(
                                u['display_name'] as String? ??
                                    context.strings.adminUsersUnnamed,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u['email'] as String? ?? '',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (u['app_version'] != null)
                                    Text(
                                      context.strings.adminUsersVersion(
                                            '${u['app_version']}',
                                          ) +
                                          '${u['platform'] == null ? '' : ' • ${u['platform']}'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  if (isBanned && u['ban_reason'] != null)
                                    Text(
                                      context.strings.adminUsersReason(
                                        '${u['ban_reason']}',
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.errorColor,
                                      ),
                                    ),
                                ],
                              ),
                              trailing:
                                  isAdmin
                                      ? const Chip(label: Text('admin'))
                                      : isBusy
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              isBanned
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.errorColor,
                                        ),
                                        onPressed:
                                            () =>
                                                isBanned
                                                    ? _setBanned(u, false)
                                                    : _confirmBan(u),
                                        child: Text(
                                          isBanned
                                              ? context.strings.adminUsersUnban
                                              : context.strings.adminUsersBan,
                                        ),
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
