import 'package:flutter/material.dart';
import '../../models/notification.dart';
import '../../models/recipe.dart';
import '../../services/notification_service.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  final RecipeService _recipeService = RecipeService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Nie udało się załadować powiadomień';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllAsRead();
      setState(() {
        _notifications = _notifications
            .map((n) => AppNotification(
                  id: n.id,
                  notificationType: n.notificationType,
                  message: n.message,
                  recipeId: n.recipeId,
                  recipeName: n.recipeName,
                  commentId: n.commentId,
                  isRead: true,
                  createdAt: n.createdAt,
                ))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Nie udało się oznaczyć wszystkich jako przeczytane')),
      );
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    if (!notification.isRead) {
      try {
        await _service.markAsRead(notification.id);
        setState(() {
          final index = _notifications.indexWhere((n) => n.id == notification.id);
          if (index != -1) {
            _notifications[index] = AppNotification(
              id: notification.id,
              notificationType: notification.notificationType,
              message: notification.message,
              recipeId: notification.recipeId,
              recipeName: notification.recipeName,
              commentId: notification.commentId,
              isRead: true,
              createdAt: notification.createdAt,
            );
          }
        });
      } catch (_) {
        // Nieudane oznaczenie jako przeczytane nie powinno blokować
        // przejścia do przepisu — użytkownik i tak chce go zobaczyć.
      }
    }

    if (notification.recipeId == null || !mounted) return;
    try {
      final recipe = await _recipeService.getRecipe(notification.recipeId!);
      if (!mounted) return;
      Navigator.of(context).pushNamed('/recipe/detail', arguments: recipe);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Nie udało się otworzyć przepisu')),
      );
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'przed chwilą';
    if (diff.inHours < 1) return '${diff.inMinutes} min temu';
    if (diff.inDays < 1) return '${diff.inHours} godz. temu';
    if (diff.inDays < 7) return '${diff.inDays} dni temu';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Powiadomienia'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Oznacz wszystkie'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: AppTheme.textSecondary)))
              : _notifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 48, color: AppTheme.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'Brak powiadomień',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppTheme.primaryColor,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final n = _notifications[index];
                          return Material(
                            color: n.isRead ? AppTheme.surfaceColor : AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openNotification(n),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!n.isRead)
                                      Container(
                                        margin: const EdgeInsets.only(top: 6, right: 10),
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n.message,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _relativeTime(n.createdAt),
                                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
