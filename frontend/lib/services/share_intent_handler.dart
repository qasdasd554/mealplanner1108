import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/recipes/ai_add_recipe_screen.dart';

/// Nasłuchuje na treści udostępnione z innych aplikacji (np. link do
/// filmiku udostępniony wprost z TikToka przez systemowe menu
/// "Udostępnij") i otwiera ekran rozpoznawania przepisu przez AI z
/// gotowym, wypełnionym linkiem.
///
/// UWAGA: to WŁASNA implementacja przez MethodChannel (patrz
/// android/.../MainActivity.kt), nie zewnętrzny pakiet z pub.dev. Dwie
/// kolejne biblioteki do tego celu (receive_sharing_intent,
/// listen_receive_sharing_intent) miały problemy z budowaniem — ten kod
/// używa wyłącznie stabilnego, wieloletniego API Fluttera (MethodChannel)
/// i komunikuje się z natywnym kodem Kotlin napisanym specjalnie dla tej
/// aplikacji, więc nie zależy od jakości/aktualności żadnej zewnętrznej
/// paczki.
///
/// UWAGA (naprawa — błąd "wraca do ekranu głównego po udostępnieniu"):
/// obsługuje TERAZ WYŁĄCZNIE przypadek "gorącego startu" — aplikacja
/// jest już otwarta, natywna strona wypycha tekst przez `onSharedText`
/// (patrz MainActivity.onNewIntent). Przypadek "zimnego startu" (link
/// otwiera aplikację od zera) jest teraz w CAŁOŚCI obsługiwany przez
/// SplashScreen — wcześniej OBA miejsca niezależnie pytały o
/// `getInitialSharedText`, co samo w sobie nie było błędem (wartość jest
/// zwracana tylko raz, więc drugie zapytanie po prostu dostawało null),
/// ale SplashScreen i tak NASTĘPNIE bezwarunkowo nadpisywał cokolwiek
/// ShareIntentHandler zdążył otworzyć, przez swoje własne
/// pushReplacementNamed('/home'). Scalenie decyzji o trasie w JEDNYM
/// miejscu (SplashScreen) eliminuje ten problem u źródła.
class ShareIntentHandler {
  static const MethodChannel _channel = MethodChannel('com.meal_planner_polska_v1/share_intent');
  static final RegExp _urlPattern = RegExp(r'https?://\S+');

  static String? extractUrl(String? sharedText) {
    if (sharedText == null) return null;
    final raw = _urlPattern.firstMatch(sharedText)?.group(0);
    if (raw == null) return null;
    final url = raw.replaceFirst(RegExp(r'[.,;!?\)\]\}]+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) return null;
    return url;
  }

  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedText') {
        _handleSharedText(call.arguments as String?, navigatorKey);
      }
    });
    // Zimny start obsługuje SplashScreen; po wznowieniu iOS może już
    // przekazać link z rozszerzenia do działającej aplikacji.
    _channel.invokeMethod<void>('shareChannelReady').catchError((_) {});
  }

  static void _handleSharedText(String? sharedText, GlobalKey<NavigatorState> navigatorKey) {
    if (sharedText == null || sharedText.isEmpty) return;

    final url = extractUrl(sharedText);
    if (url == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.push(
        MaterialPageRoute(builder: (_) => AiAddRecipeScreen(
          initialUrl: url,
          autoStartImport: true,
        )),
      );
    });
  }
}
