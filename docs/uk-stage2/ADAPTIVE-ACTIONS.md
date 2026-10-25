# Dopasowanie opcji dodawania przepisu

Zatwierdzony przez właściciela wyjątek od braku zmian układu: na wąskim
ekranie/powiększonej czcionce plakietka Premium może przejść pod nazwę.

## Decyzja UI/UX (Stark)

- Zadanie: wybrać zdjęcie, tekst, link albo ręczne dodanie przepisu, bez
  zmiany kosztu, uprawnień i tras. Powracający użytkownik, częste działanie.
- Platformy/track: istniejący Flutter dla Android/iOS; bez zmiany frameworka.
- Obiekt/akcja: nazwany sposób dodania przepisu; jedno tapnięcie całego wiersza.
- Struktura: dotychczasowy natywny ListTile w obecnym obramowaniu. Przy braku
  miejsca pomocnicza złota plakietka przechodzi do opisu. Na standardowej
  szerokości pozostaje po prawej, tak jak wcześniej.
- Styl: zachowane motywy, złote oznaczenie Premium, ikony, padding i kolory.
  Nie zmniejszamy dostępnościowej czcionki. Plakietka może zawijać tekst.
- Warunek: efektywna szerokość komponentu przy aktualnym rozmiarze tekstu
  poniżej 340 px. To warunek kontenera, a nie wykrywanie modelu telefonu.
- Stan/powrót: bez nowego stanu asynchronicznego, animacji i bibliotek;
  zamknięcie arkusza i powrót fokusu pozostają własnością obecnej trasy.
- Zastosowanie: opcje w Przepisach i wspólnym menu Dodaj na Starcie/Premium.
- Dowód regresji: na 320 px/150% tekstu poprzedni ListTile oddawał całą
  szerokość plakietce; obszar nazwy miał szerokość 0. Krótszy angielski
  skrót PTS nie wystarczył. Adaptacja zachowuje widoczną, klikalną nazwę.
- Referencje Stark: task-ergonomics, interaction-state-matrix i responsive-
  adaptation-gate: pierwszeństwo nazwy akcji, reflow zamiast ściskania,
  kontrola na powiększonym tekście i brak ukrywania warunku Premium.

Testy renderujące obejmują 320/390 px, tekst 100/200%, motyw jasny/ciemny,
położenie plakietki, szerokość nazwy i działanie tapnięcia. Test pełnego
ekranu obejmuje też wybór i przewijanie menu przy 320 px/150%.
To nie zastępuje VoiceOver/TalkBack ani testu na fizycznym urządzeniu.

Opcjonalne PNG z testu komponentu powstają przy
`flutter test --dart-define=CAPTURE_UK_LAYOUT=true test/widgets/adaptive_action_tile_test.dart`.
Są dowodem lokalnego renderowania, nie zdjęciem z telefonu; używają
dostępnej lokalnej czcionki Arial zamiast fontu testowego Ahem.

## Kontrola renderu — 2026-10-16

Obejrzano oba PNG 320 px/200% po załadowaniu MaterialIcons (wcześniejszy
render testowy nie miał fontu ikon). Nazwa ma pełną czytelną szerokość,
opis zawija się pod nią, złota plakietka pozostaje widoczna. Motyw ciemny
i jasny zachowują ten sam porządek; bez obcinania etykiet i zmiany ikon.
Kontrola komponentu: pass w tym zakresie. Pozostałe ryzyka: fonty systemowe
na iOS/Androidzie, VoiceOver/TalkBack i rzeczywisty ekran wymagają testu
urządzenia. Nie jest to akceptacja całego rynku UK ani natywnego wydania.
