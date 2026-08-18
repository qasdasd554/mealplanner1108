import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../screens/recipes/ai_add_recipe_screen.dart';

/// Nasłuchuje na treści udostępnione z innych aplikacji (np. link do
/// filmiku udostępniony wprost z TikToka przez systemowe menu
/// "Udostępnij") i otwiera ekran rozpoznawania przepisu przez AI z
/// gotowym, wypełnionym linkiem.
///
/// Działa w dwóch przypadkach:
/// 1. Aplikacja jest już otwarta — udostępnienie przychodzi jako strumień.
/// 2. Aplikacja zostaje DOPIERO uruchomiona przez samo udostępnienie
///    (użytkownik miał ją zamkniętą i wybrał ją z menu "Udostępnij") —
///    tzw. zimny start, obsługiwany osobno przez `getInitialMedia()`.
///
/// UWAGA (znane ograniczenie): jeśli użytkownik nie jest jeszcze
/// zalogowany w momencie udostępnienia, ekran rozpoznawania i tak się
/// otworzy, ale próba rozpoznania przepisu zakończy się błędem
/// autoryzacji (401) — istniejąca obsługa błędów na tym ekranie pokaże
/// wtedy czytelny komunikat. Pełne "zapamiętaj i wróć po zalogowaniu"
/// to możliwe do zbudowania rozszerzenie, jeśli okaże się potrzebne.
class ShareIntentHandler {
  static StreamSubscription? _intentSub;
  static final RegExp _urlPattern = RegExp(r'https?://\S+');

  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) => _handleShared(files, navigatorKey),
      onError: (_) {
        // Cicho ignorujemy błędy strumienia — to nie jest krytyczna
        // funkcja aplikacji, nie chcemy przez nią wywalać całej reszty.
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleShared(files, navigatorKey);
      ReceiveSharingIntent.instance.reset();
    });
  }

  static void _handleShared(List<SharedMediaFile> files, GlobalKey<NavigatorState> navigatorKey) {
    if (files.isEmpty) return;

    final sharedText = files.first.path;
    final match = _urlPattern.firstMatch(sharedText);
    if (match == null) return;
    final url = match.group(0)!;

    // Poczekaj na pełną inicjalizację nawigatora (zwłaszcza przy zimnym
    // starcie, gdy aplikacja dopiero się uruchamia) przed próbą nawigacji.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.push(
        MaterialPageRoute(builder: (_) => AiAddRecipeScreen(initialUrl: url)),
      );
    });
  }

  static void dispose() {
    _intentSub?.cancel();
  }
}
