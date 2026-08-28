import '../models/notification.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _client = ApiClient();

  Future<List<AppNotification>> getNotifications() async {
    final response = await _client.get('/notifications/');
    if (response is List) {
      return response.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<int> getUnreadCount() async {
    final response = await _client.get('/notifications/unread-count');
    if (response is Map<String, dynamic>) {
      return response['unread_count'] as int? ?? 0;
    }
    return 0;
  }

  Future<void> markAsRead(String notificationId) async {
    await _client.put('/notifications/$notificationId/read');
  }

  Future<void> markAllAsRead() async {
    await _client.put('/notifications/read-all');
  }

  /// Wysyła powiadomienie do WSZYSTKICH użytkowników — wymaga
  /// uprawnień administratora (backend odrzuci zwykłe konto kodem 403).
  Future<int> sendBroadcast(String message) async {
    final response = await _client.post(
      '/notifications/admin/broadcast',
      body: {'message': message},
    );
    return (response as Map<String, dynamic>)['sent_to'] as int;
  }
}
