import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../screens/notifications/notifications_screen.dart';

/// Dzwoneczek z odznaką liczby nieprzeczytanych powiadomień. Samodzielny
/// widget ze swoim stanem — odświeża licznik przy wejściu na ekran i
/// cyklicznie w tle (odpytywanie/"polling", bo bez Firebase Cloud
/// Messaging nie ma jak dostać powiadomienia push w czasie rzeczywistym).
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final NotificationService _service = NotificationService();
  int _unreadCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Odpytuj co 30 sekund, kiedy ekran z dzwoneczkiem jest widoczny —
    // najprostszy sposób na "prawie na żywo" bez infrastruktury push.
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final count = await _service.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // Cicho ignorujemy błąd odświeżania licznika — to tylko odznaka,
      // nie ma sensu przerywać użytkownikowi pracy komunikatem o błędzie
      // za każdym razem, gdy na chwilę zniknie internet.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    // Po powrocie z listy odśwież odznakę (mogły zostać oznaczone jako
    // przeczytane).
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: _openNotifications,
          tooltip: 'Powiadomienia',
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
