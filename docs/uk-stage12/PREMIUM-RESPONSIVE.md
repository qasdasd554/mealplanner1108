# Premium — ograniczona poprawka responsywna

21.10.2026. Zgoda właściciela dotyczy wyłącznie dopasowania do małego
ekranu i powiększonego tekstu. Flutter, PL i en_GB; bez nowego projektu UI.

## Decyzja i przyczyna

Zadanie użytkownika: przeczytać korzyści, warunki triala oraz cenę przed
podjęciem decyzji. Nie zmniejszamy czcionki ani nie ukrywamy warunków.
Kolory, odstępy zwykłego widoku, kolejność, ceny i akcje pozostają te same.
Nie zmieniamy uprawnień Premium ani logiki sklepowej.

Przed poprawką oba testy 320 px / 150% nie przechodziły: sztywny nagłówek
250 px przepełniał się pionowo, a plakietka w wierszu ściskała tytuł.
Po ich naprawieniu test dotarł do dodatkowego przepełnienia etykiety triala
w karcie miesięcznej — tekst w Row nie miał elastycznego ograniczenia.

Naprawa:

- Rzeczywisty pomiar tekstu z uwzględnieniem szerokości i skali systemowej.
  Nagłówek zachowuje dokładnie 250 px, dopóki treść się w nim mieści.
- Plakietka pozostaje w oryginalnym wierszu, gdy wystarcza miejsca;
  w przeciwnym razie pojawia się pod głównym tytułem karty.
- Flexible pozwala zawijać etykietę triala w cenniku bez zmiany jej stylu.
- Istniejące przewijanie, animacje, ścieżki zakupu i przyciski pozostają.

## Weryfikacja

- 16 testów ekranu Premium: PL/GB, stany triala i błędów sklepu,
  opóźniona odpowiedź oraz zamknięcie ekranu, 320 px / 150%,
  320 px / 200% w obu motywach i poziomy ekran 740 × 320 / 150%.
- Test zwykłego widoku potwierdza nagłówek 250 px i brak nakładania się
  tytułu oraz plakietki. Dla rzeczywistych szerokości liter w dowodach
  graficznych potwierdzono oryginalną pozycję plakietki przy 390 px / 100%.
- Pełny Flutter: 518 passed, bez niepowodzeń.
- Pełny backend: 1251 passed, 41 ostrzeżeń, z ENVIRONMENT=test.
  Backend nie został zmieniony tą poprawką. Próba bez ustawienia trybu
  testowego została prawidłowo zatrzymana przez kontrolę sekretów produkcji;
  nie wyłączano tej kontroli ani nie używano sekretów produkcyjnych.
- Analiza: exit 0, 0 błędów i ostrzeżeń; 359 informacji/lintów.

Polecenie dowodów graficznych, uruchamiane lokalnie na Windows:

```powershell
flutter test --no-pub --dart-define=UK_WRITE_UI_PROOF=true test/screens/profile/premium_market_test.dart -r expanded
```

Zrzuty nagłówka i karty kontekstowej używają testowo Arial oraz ikon
Material, aby nie oceniać kwadratowych glifów domyślnej czcionki Ahem.
Testy bez tej flagi nadal używają Ahem jako konserwatywnego sprawdzianu
szerokości. Flaga nie modyfikuje fontów produkcyjnych ani obrazu aplikacji.
Cennik sprawdzono testami układu; zrzuty nie zastępują testu natywnego IAP,
TalkBack/VoiceOver ani testów na fizycznym telefonie.

- [PL, 390 px, 100%](evidence/premium-pl-390-100.png)
- [GB, 390 px, 100%](evidence/premium-gb-390-100.png)
- [PL, 320 px, 200%, jasny](evidence/premium-pl-320-200-light-top.png)
- [PL, 320 px, 200%, ciemny](evidence/premium-pl-320-200-dark-top.png)
- [GB, 320 px, 200%, jasny](evidence/premium-gb-320-200-light-top.png)
- [GB, 320 px, 200%, ciemny](evidence/premium-gb-320-200-dark-top.png)

Nie wykonano wdrożenia, AAB/IPA, zmiany numeru wersji ani aktywacji UK.
Pozostałe bramki projektu UK są wyszczególnione w UK-EXPANSION.md.
