import '../services/api_client.dart';

/// Zamienia dowolny wyjątek (najczęściej [ApiException]) na czytelny,
/// przyjazny komunikat do pokazania użytkownikowi.
///
/// UWAGA (naprawa): wcześniej w ośmiu różnych miejscach aplikacji ten sam
/// wzorzec — `e.toString().replaceAll('ApiException:', '').trim()` —
/// usuwał TYLKO tekst "ApiException:", ale zostawiał widoczny numer
/// kodu w nawiasach kwadratowych, bo `ApiException.toString()` zwraca
/// `'ApiException: [422] wiadomość'`. Efekt: użytkownik widział np.
/// `"[422] AI nie rozpoznało żadnych składników..."` — techniczny,
/// nieprzyjazny prefiks przed skądinąd sensowną wiadomością. Ta funkcja
/// pokazuje SAMĄ wiadomość, a dla najczęstszych kodów dokłada
/// przyjazniejszą ramę.
String friendlyError(Object error) {
  if (error is ApiException) {
    switch (error.statusCode) {
      case 401:
        return 'Musisz być zalogowany, żeby to zrobić.';
      case 403:
        return error.message;
      case 404:
        return error.message;
      case 422:
        return error.message;
      case 429:
        return 'Zbyt wiele prób w krótkim czasie — spróbuj ponownie za chwilę.';
      case 503:
        return 'Usługa jest chwilowo niedostępna. Spróbuj ponownie za chwilę.';
      default:
        if (error.statusCode >= 500) {
          return 'Coś poszło nie tak po naszej stronie. Spróbuj ponownie za chwilę.';
        }
        return error.message;
    }
  }
  // Nie-ApiException (np. błąd sieci złapany gdzie indziej) — pokaż
  // wiadomość bez żadnego technicznego opakowania Dart/Exception.
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
