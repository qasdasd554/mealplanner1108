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

class _TurnstileWidgetState extends State<TurnstileWidget> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
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
          onWebResourceError: (_) {
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
  }

  @override
  Widget build(BuildContext context) {
    if (!TurnstileWidget.isEnabled) return const SizedBox.shrink();

    if (_failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
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
        ],
      ),
    );
  }
}
