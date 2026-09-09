import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';

/// Obsługa powiadomień push (Firebase Cloud Messaging).
///
/// CAŁOŚĆ jest odporna na brak konfiguracji: jeśli pliki Firebase
/// (`google-services.json` / `GoogleService-Info.plist`) nie zostały
/// jeszcze wgrane, `Firebase.initializeApp()` rzuca wyjątek, który tutaj
/// przechwytujemy — aplikacja działa dalej normalnie, tylko bez
/// powiadomień systemowych. Dzięki temu można wydać wersję z tym kodem
/// zanim Firebase zostanie skonfigurowany.
class PushService {
  static final PushService _instance = PushService._();
  factory PushService() => _instance;
  PushService._();

  final ApiClient _client = ApiClient();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _available = false;
  String? _currentToken;

  /// Czy Firebase wystartował poprawnie (są pliki konfiguracyjne).
  bool get isAvailable => _available;

  /// Uruchamiane RAZ przy starcie aplikacji, przed zalogowaniem.
  /// Nie prosi jeszcze o zgodę — o to pytamy dopiero po zalogowaniu
  /// (patrz [registerForUser]), żeby pierwszym, co widzi nowy użytkownik,
  /// nie było systemowe okno z prośbą o pozwolenie.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      debugPrint('Firebase niedostępny — push wyłączony: $e');
      _available = false;
      return;
    }

    // Kanał wymagany na Androidzie 8+; bez niego dymek przy otwartej
    // aplikacji w ogóle się nie pokaże.
    const androidChannel = AndroidNotificationChannel(
      'meal_planner_default',
      'Powiadomienia',
      description: 'Komentarze, konkursy i informacje z aplikacji',
      importance: Importance.high,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Zgody prosimy osobno przez firebase_messaging, żeby nie
          // wyświetlić użytkownikowi DWÓCH okien z tym samym pytaniem.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Gdy aplikacja jest OTWARTA, system nie pokazuje dymka sam —
    // musimy zrobić to ręcznie, inaczej powiadomienie przepadnie
    // niezauważone.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meal_planner_default',
          'Powiadomienia',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Prosi o zgodę i rejestruje token na koncie zalogowanego użytkownika.
  /// Wołane PO zalogowaniu — wtedy prośba o pozwolenie ma dla użytkownika
  /// zrozumiały kontekst.
  Future<void> registerForUser() async {
    if (!_available) return;
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // Użytkownik odmówił — uszanuj to i nie próbuj ponownie przy
        // każdym uruchomieniu.
        return;
      }

      // NA iOS trzeba NAJPIERW poczekać na token APNs od systemu.
      // getToken() z Firebase potrzebuje go, żeby wystawić własny token —
      // wywołane za wcześnie zwraca null albo rzuca wyjątek. Ponieważ
      // wyjątek jest tu połykany, urządzenie po prostu NIGDY się nie
      // rejestrowało i push na iPhone'ach nie działał w ogóle.
      // Android tego wymogu nie ma, dlatego tam działało od razu.
      if (Platform.isIOS) {
        var apnsToken = await messaging.getAPNSToken();
        // System potrafi zwrócić token dopiero po chwili — próbujemy
        // kilka razy zamiast poddawać się po pierwszym null.
        for (var i = 0; i < 5 && apnsToken == null; i++) {
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await messaging.getAPNSToken();
        }
        if (apnsToken == null) {
          debugPrint('Brak tokenu APNs — push na tym urządzeniu nie zadziała.');
          return;
        }
      }

      final token = await messaging.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }

      // FCM potrafi odświeżyć token samodzielnie (np. po reinstalacji);
      // bez nasłuchu backend zostałby ze starym i push przestałby
      // docierać, bez żadnego widocznego błędu.
      messaging.onTokenRefresh.listen(_sendTokenToBackend);
    } catch (e) {
      debugPrint('Nie udało się zarejestrować powiadomień push: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _client.post(
        '/notifications/device-token',
        body: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );
      _currentToken = token;
    } catch (e) {
      debugPrint('Nie udało się zapisać tokenu urządzenia: $e');
    }
  }

  /// Wyrejestrowuje urządzenie przy wylogowaniu — inaczej telefon dalej
  /// dostawałby powiadomienia konta, z którego użytkownik właśnie wyszedł.
  Future<void> unregister() async {
    if (!_available || _currentToken == null) return;
    try {
      // Token idzie w adresie, a nie w ciele żądania: ApiClient.delete
      // nie obsługuje ciała, a zmiana tej wspólnej metody dla jednego
      // przypadku psułaby wszystkie pozostałe wywołania DELETE.
      await _client.post(
        '/notifications/device-token/remove',
        body: {'token': _currentToken},
      );
    } catch (_) {
      // Wylogowanie NIE MOŻE się nie udać z powodu problemu z push.
    }
    _currentToken = null;
  }
}
