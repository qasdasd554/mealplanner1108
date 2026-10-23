# 1.0.69+270 — poprawki przepisów, planów i zakupów

Podstawa paczki: dokładny eksport Codespace b395897982251ddaa68520e91d57b45b536292b4,
wersja 1.0.68+269. Wersja frontend/API zgodna; UK nadal wyłączone.

- Generowanie/edycja AI otrzymuje tylko sprawdzony słownik składników kulinarnych.
  Przypadkowe produkty i gotowe posiłki z katalogu sklepowego nie kształtują składu
  dania. Pełny katalog jest używany dopiero do dopasowania wybranych składników.
- Wycofano podmianę składnika na podstawie samego podobieństwa pisowni. Nieznane
  składniki zachowują nazwę/ilość, są szukane zewnętrznie i w razie potrzeby
  otrzymują prywatny, oznaczony szacunek; nie są publikowane jako dane etykiety.
- Niepełne makro nie zamienia całego dania w 0 kcal. Dostępna jest znana część
  sumy z opisem; dane oszacowane są oddzielnie oznaczone. Dziennik nadal nie
  przyjmuje niepełnego wyniku jako pełnego posiłku z zerami.
- Naprawiono doczytywanie tagów podczas serializacji wygenerowanego planu,
  odtworzone po przebudowie listy zakupów z populate_existing.
- Brak ceny koszyka nie jest zerową ceną. Zmiana sklepu listy zachowuje skład,
  ilości i stan kupionych produktów również przy niepełnej wycenie.
- Zatwierdzony ekran Premium po wykorzystaniu tygodniowego limitu list:
  raz na sesję, potem krótki komunikat; powrót bez utraty wyboru, trial tylko
  po potwierdzeniu sklepu, bez automatycznego zakupu.

Powiadomienie aktualizacji ma pięć bieżących punktów w PL i EN. Do paczki wchodzą
też lokalne etapy 30–31 UK (komunikaty przepisów i mapowanie nazw), bez aktywacji
UK, nowych uprawnień, migracji produkcyjnej bazy i importu całego OFF.

Wyniki i granice kontroli: osobny raport weryfikacji paczki. Potrzebny jest
rzeczywisty build AAB w Codespace oraz test telefonu i usług zewnętrznych.
