# 1.0.77+278 — listy zakupów i Dziennik PL/UK

- Poprawiono tłumaczenia starszych zapisów jednostek, m.in. łyżki i łyżeczki.
- Powtarzające się składniki są sumowane po przeliczeniu zgodnych miar.
  Nieznane przeliczniki pozostają nieznane, bez wymyślania masy opakowania.
- Starsze niezaznaczone pozycje wygenerowane na listach UK są porządkowane
  przy odczycie. Zakupione pozycje oraz ręczne dodatki pozostają zachowane.
- Jajka i znane produkty sztukowe pokazują orientacyjną liczbę sztuk oraz
  pomocniczą masę. Podstawa wyceny i przeliczenia spiżarni nie są zmieniane.
- Potwierdzone oferty wybranego sklepu mają pierwszeństwo. Osobno pokazujemy
  zatwierdzone przez użytkownika zamienniki katalogowe z ceną orientacyjną
  na określoną ilość i informacją o konieczności sprawdzenia dostępności.
  Nie tworzymy fikcyjnych ofert ani opakowań sklepowych.
- Poprawiono dopasowanie przycisków nawodnienia i wiersza makro w Dzienniku.
- Zaktualizowano cztery najważniejsze punkty powiadomienia o aktualizacji.

Wymagane jest wdrożenie backendu oraz nowej aplikacji. Brak nowych zależności
i migracji. Nie zmieniono kraju kont ani rozdzielenia przepisów PL/UK.
Jeżeli APP_VERSION na Renderze jest ustawione ręcznie, ustaw 1.0.77.
Nie podnoś wymaganej publicznej wersji przed udostępnieniem jej w sklepach.
