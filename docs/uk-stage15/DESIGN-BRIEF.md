# UK: kalkulator, wyłącznie lokalizacja i zatwierdzona korekta dopasowania

- Użytkownik i zadanie: istniejący użytkownik PL/GB wypełnia kalkulator,
  wybiera otrzymany cel i zapisuje go do swojego profilu.
- Platformy/track: obecny branded Flutter na Androidzie i iOS; bez zmiany
  frameworka, nawigacji ani obietnicy natywnego renderowania.
- Obiekt/akcja: formularz -> wynik serwera -> wybór celu -> zapis profilu.
  Identyfikatory female/male i activity_level, kg/cm oraz obliczenia bez zmian.
- Struktura: istniejąca pojedyncza przewijana kolumna; te same pola, kolejność,
  przyciski, slider, kafelki wyników i proporcje makro.
- Styl: zachowane obecne kolory, typografia, obramowania i odstępy aplikacji;
  żadnych nowych grafik, bibliotek animacji, promocji ani funkcji.
- Stany: dane z profilu, walidacja, obliczanie, błąd/retry, wynik, zapis/pop.
- Adaptacja zaakceptowana przez właściciela: zawijanie wartości makro do
  kolejnego wiersza wyłącznie przy braku miejsca. Zwykły układ pozostaje
  poziomy, bez zmniejszania czcionki, zmiany kolorów i treści liczb.
  Początkowa hipoteza o wyborze płci była błędna: pełne FlutterErrorDetails
  wskazało Row w sekcji makro. Niepotrzebny eksperyment z pionowym wyborem
  płci wycofano, a właściciel osobno zatwierdził naprawę wiersza makro.
- Kolejna osobno zaakceptowana adaptacja: trzy istniejące cele jeden pod
  drugim przy wąskim kontenerze (<320 px po odjęciu marginesów) i tekście
  >120%. Standardowe 390 px/100% nadal ma trzy kolumny. Zrzut 320 px/150%
  pokazał, że bez tego nazwy łamały się w środku wyrazów.
- Scroll ownership: dotychczasowy SingleChildScrollView i SafeArea.
- Referencje: Stark audit/repair (ui-audit-rubric, visual-repair-playbook),
  cross-platform decision brief, responsive containment/adaptation oraz
  text-resilience/localization. Dotyczą konkretnego overflow, nie redesignu.
- Akceptacja: PL i GB dają te same canonical payloady, wyniki i zapis celu;
  320 px/150% tekstu bez RenderFlex overflow; zwykły układ poziomy;
  render kontrolny z rzeczywistą czcionką i osobny test Ahem.
- Ograniczenie: screenshot testu widgetowego nie zastępuje testu natywnego
  Android/iOS z klawiaturą i systemowym skalowaniem tekstu.
