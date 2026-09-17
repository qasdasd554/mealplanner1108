import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';

/// Bramka CAPTCHA (Cloudflare Turnstile) pokazywana przed logowaniem
/// i rejestracją.
///
/// Turnstile jest komponentem webowym, więc renderujemy go w WebView,
/// ładując stronę hostowaną na GitHub Pages (`docs/captcha.html`).
/// Bezpośrednie wstrzyknięcie kodu HTML do WebView nie zadziała, bo
/// Turnstile sprawdza domenę uruchomienia i odrzuca `about:blank`.
///
/// Gdy `ApiConfig.turnstileSiteKey` jest puste, widget zgłasza gotowość
/// natychmiast i niczego nie pokazuje — dzięki temu aplikacja działa
/// normalnie, zanim klucze zostaną skonfigurowane.
class TurnstileWidget extends StatefulWidget {
  /// Wywoływane z tokenem po pomyślnej weryfikacji, albo z `null`, gdy
  /// token wygasł lub wystąpił błąd (wtedy przycisk wysyłki powinien
  /// zostać ponownie zablokowany).
  final ValueChanged<String?> onToken;

  const TurnstileWidget({super.key, required this.onToken});

  static bool get isEnabled => ApiConfig.turnstileSiteKey.isNotEmpty;

  @override
  State<TurnstileWidget> createState() => _TurnstileWidgetState();
}

class _TurnstileWidgetState extends State<TurnstileWidget> with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _failed = false;

  /// Znacznik jednorazowego wygaszenia licznika czasu — bez niego,
  /// gdyby _loadTimeout odpalił się PO tym, jak strona już się wczytała,
  /// mógłby błędnie oznaczyć sprawny widget jako zepsuty.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!TurnstileWidget.isEnabled) {
      // Bramka wyłączona — zgłaszamy "gotowe" po pierwszej klatce, żeby
      // ekran logowania nie czekał w nieskończoność na token.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onToken('');
      });
      return;
    }
    _initWebView();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // NAPRAWA: po wyjściu z aplikacji i powrocie do niej widget CAPTCHA
    // potrafił zostać "martwy" — WebView na Androidzie wstrzymuje
    // wykonywanie JS w tle, więc odliczanie ważności tokenu Turnstile
    // (ok. 5 minut) i wewnętrzne odświeżanie wyzwania nie działały,
    // jak powinny. Po powrocie z tła użytkownik miał widget, który
    // wyglądał na sprawny, ale token nigdy nie przychodził — a próba
    // logowania kończyła się w kółko tym samym błędem, bez wyjaśnienia.
    // Przeładowanie strony po wznowieniu daje ZAWSZE świeże wyzwanie.
    if (state == AppLifecycleState.resumed &&
        TurnstileWidget.isEnabled &&
        _controller != null) {
      widget.onToken(null);
      setState(() {
        _isLoading = true;
        _failed = false;
      });
      _controller!.reload();
      _armLoadTimeout();
    }
  }

  /// Gdy strona nie zgłosi się w rozsądnym czasie — ani `onPageFinished`,
  /// ani `onWebResourceError` — pokazujemy stan "nie udało się" zamiast
  /// zostawiać użytkownika przed kręcącym się w nieskończoność kółkiem
  /// bez żadnej możliwości działania. Typowy powód: sieć, która po cichu
  /// blokuje connectivity do Cloudflare (np. część sieci firmowych/szkolnych)
  /// bez zwracania jawnego błędu.
  void _armLoadTimeout() {
    final generation = ++_loadGeneration;
    Future.delayed(const Duration(seconds: 12), () {
      if (!mounted || generation != _loadGeneration) return;
      if (_isLoading) {
        setState(() {
          _isLoading = false;
          _failed = true;
        });
      }
    });
  }

  void _initWebView() {
    final theme = AppTheme.isDark ? 'dark' : 'light';
    final uri = Uri.parse(
      '${ApiConfig.turnstilePageUrl}'
      '?sitekey=${Uri.encodeComponent(ApiConfig.turnstileSiteKey)}'
      '&theme=$theme',
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'TurnstileChannel',
        onMessageReceived: (message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            switch (data['type']) {
              case 'token':
                widget.onToken(data['token'] as String?);
                break;
              case 'expired':
              case 'error':
                // Token przestał być ważny (Turnstile odnawia go co ok.
                // 5 minut) albo wyzwanie się nie powiodło — cofamy zgodę.
                widget.onToken(null);
                break;
            }
          } catch (_) {
            widget.onToken(null);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            // WAŻNE: onWebResourceError zgłasza KAŻDY nieudany zasób, nie
            // tylko samą stronę — a GitHub Pages zwraca 404 dla
            // /favicon.ico, o który przeglądarka pyta automatycznie. Bez
            // sprawdzenia isForMainFrame wystarczało to, żeby pokazać
            // "Nie udało się wczytać weryfikacji", mimo że strona i widget
            // działały poprawnie. Interesuje nas wyłącznie błąd głównego
            // dokumentu.
            if (error.isForMainFrame != true) return;
            if (mounted) {
              setState(() {
                _isLoading = false;
                _failed = true;
              });
            }
          },
        ),
      )
      ..loadRequest(uri);
    _armLoadTimeout();
  }

  @override
  Widget build(BuildContext context) {
    if (!TurnstileWidget.isEnabled) return const SizedBox.shrink();

    if (_failed) {
      // Gdy weryfikacji naprawdę nie da się wczytać (np. sieć blokuje
      // Cloudflare), NIE blokujemy logowania na stałe. To spójne
      // z tym, jak backend traktuje WŁASNĄ awarię połączenia z Cloudflare
      // (patrz verify_turnstile_token — też przepuszcza żądanie zamiast
      // blokować cały serwis z powodu zewnętrznej usługi). Skoro obecnie
      // backend i tak nie wymaga jeszcze tokenu (bramka wyłączona do
      // czasu publikacji), pominięcie tutaj niczego nie osłabia; gdy
      // bramka zostanie włączona, serwer i tak odrzuci puste żądanie —
      // to on jest ostatecznym strażnikiem, nie ten ekran.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_off, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nie udało się wczytać weryfikacji. Sprawdź połączenie.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _failed = false;
                      _isLoading = true;
                    });
                    _initWebView();
                  },
                  child: const Text('Ponów'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => widget.onToken(''),
                child: Text(
                  'Kontynuuj mimo to',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Stała wysokość: widget Turnstile ma 65 px, plus zapas na komunikat
    // o błędzie, który Cloudflare potrafi pokazać w tym samym miejscu.
    return SizedBox(
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          // Ręczne odświeżenie dostępne ZAWSZE, nie tylko po twardym
          // błędzie — gdyby widget "zawiesił się" bez wywołania żadnego
          // z callbacków (np. zablokowany JS bez zgłoszenia błędu),
          // użytkownik ma jak sam wymusić nową próbę, zamiast czekać
          // 12 sekund na automatyczny timeout albo zamykać aplikację.
          Positioned(
            right: 0,
            top: 4,
            child: IconButton(
              icon: Icon(Icons.refresh, size: 16, color: AppTheme.textSecondary),
              tooltip: 'Odśwież weryfikację',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                widget.onToken(null);
                setState(() {
                  _isLoading = true;
                  _failed = false;
                });
                _controller?.reload();
                _armLoadTimeout();
              },
            ),
          ),
        ],
      ),
    );
  }
}
