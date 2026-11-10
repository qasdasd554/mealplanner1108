/// Statyczna lista praktycznych porad kulinarnych ("life hacków") —
/// oryginalne, ogólnie znane triki kuchenne, napisane własnymi słowami.
/// Świadomie NIE pobierane z żadnego API/backendu — to treść, która się
/// nie zmienia często, więc trzymanie jej lokalnie w aplikacji jest
/// prostsze i szybsze niż dodawanie do tego osobnej infrastruktury
/// backendowej.
class CookingTip {
  final String title;
  final String tip;
  final IconIndex icon;

  const CookingTip({
    required this.title,
    required this.tip,
    required this.icon,
  });
}

/// Prosty, bezpieczny sposób na przypisanie ikony bez importowania
/// całego pakietu Material w tym pliku z czystymi danymi — mapowanie na
/// prawdziwą IconData dzieje się w widgecie, który to wyświetla.
enum IconIndex { pasta, vegetable, meat, baking, storage, general }

/// Presentation locale is selected by the immutable account market upstream.
List<CookingTip> cookingTipsFor(String localeName) => switch (localeName
    .split('_')
    .first) {
  'en' => kCookingTipsEn,
  'de' => kCookingTipsDe,
  _ => kCookingTips,
};

/// Preserve the existing day-of-year rotation exactly, including local dates.
int cookingTipIndexForDate(DateTime date) =>
    date.difference(DateTime(date.year, 1, 1)).inDays % kCookingTips.length;

const List<CookingTip> kCookingTips = [
  CookingTip(
    title: "Woda z makaronu to złoto",
    tip:
        "Zanim odcedzisz makaron, zachowaj pół szklanki wody z gotowania. Skrobia w niej zawarta pomaga sosowi lepiej \"chwycić się\" makaronu zamiast spływać na dno talerza.",
    icon: IconIndex.pasta,
  ),
  CookingTip(
    title: "Sól dodawaj dla smaku",
    tip:
        "Posól wodę do makaronu lub ziemniaków według przepisu i zamieszaj, aby sól się rozpuściła. Sól służy tu doprawieniu potrawy — jej zwykła ilość nie przyspiesza istotnie zagotowania wody.",
    icon: IconIndex.pasta,
  ),
  CookingTip(
    title: "Zimna cebula to mniej łez",
    tip:
        "Schłodzenie cebuli w lodówce przez 15-20 minut przed krojeniem znacząco ogranicza uwalnianie substancji drażniącej oczy.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Awokado bez brązowienia",
    tip:
        "Skrop przekrojone awokado sokiem z cytryny lub limonki — kwas spowalnia utlenianie i dłużej zachowuje zielony kolor.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Sypki ryż zaczyna się przed gotowaniem",
    tip:
        "Opłucz ryż pod zimną wodą, aż woda przestanie być mętna — usuwa to nadmiar skrobi z powierzchni ziaren, dzięki czemu ziarna mniej się sklejają.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Przygotuj mięso tuż przed smażeniem",
    tip:
        "Trzymaj surowe mięso w lodówce do rozpoczęcia przygotowania. Kawałki o podobnej grubości łatwiej usmażyć równomiernie; nie trzeba pozostawiać ich na blacie, aby osiągnęły temperaturę pokojową.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Łatwiejsze obieranie jajek",
    tip:
        "Zaraz po ugotowaniu na twardo wrzuć jajka do zimnej wody na kilka minut. Nagła zmiana temperatury ułatwia oddzielenie skorupki od białka.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Świeże zioła jak bukiet kwiatów",
    tip:
        "Pietruszkę, koperek czy natkę trzymaj w szklance z odrobiną wody w lodówce, jak kwiaty w wazonie — wytrzymają znacznie dłużej niż w foliowej torebce.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Więcej soku z cytrusów",
    tip:
        "Przed wyciśnięciem przetocz cytrynę czy limonkę mocno dłonią po blacie — rozbija to komórki wewnątrz i pozwala wycisnąć zauważalnie więcej soku.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Nie przepełniaj patelni",
    tip:
        "Zbyt duża ilość składników naraz obniża temperaturę patelni — zamiast się smażyć, warzywa czy mięso zaczynają się dusić we własnym soku. Lepiej smażyć partiami.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Ostry nóż jest bezpieczniejszy",
    tip:
        "Tępy nóż wymaga więcej siły i częściej się ześlizguje — to on, nie ostry, jest częstszą przyczyną skaleczeń w kuchni.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Zamrażaj zioła w oliwie",
    tip:
        "Posiekane świeże zioła zalane oliwą i zamrożone w kostkach lodu to gotowa baza do sosów i duszenia na kolejne tygodnie.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Czerstwy chleb wraca do życia",
    tip:
        "Skrop czerstwą bułkę czy chleb odrobiną wody i podgrzej kilka minut w piekarniku — para wodna przywraca miękkość na środku, a skórka znów robi się chrupiąca.",
    icon: IconIndex.baking,
  ),
  CookingTip(
    title: "Ratunek dla zbyt słonego sosu",
    tip:
        "Dodawaj małymi porcjami niesolony bulion, wodę lub inne niesolone składniki pasujące do sosu i próbuj po każdej zmianie. Ziemniak nie wybiera z sosu samej soli — wchłania również płyn, więc nie jest pewnym sposobem na odsolenie potrawy.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Kwas zmiękcza mięso",
    tip:
        "Odrobina soku z cytryny, octu albo jogurtu w marynacie pomaga rozluźnić włókna mięsa, dzięki czemu po usmażeniu jest bardziej kruche.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Rozgrzewaj patelnię zgodnie z instrukcją",
    tip:
        "Sposób rozgrzewania zależy od rodzaju patelni. Przy powłoce nieprzywierającej stosuj zalecenia producenta i nie przegrzewaj pustego naczynia; dodaj tłuszcz, jeśli wymaga go przepis, i nie dopuszczaj do jego dymienia.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Ziemniaki z dala od cebuli",
    tip:
        "Przechowywane razem przyspieszają sobie nawzajem kiełkowanie i psucie się — trzymaj je w oddzielnych, ciemnych miejscach.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Zielone warzywa zostają zielone",
    tip:
        "Krótko gotuj brokuły czy fasolkę w osolonym wrzątku, a zaraz potem przelej zimną wodą — zatrzymuje to proces gotowania i zachowuje intensywny kolor.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Miód bez lepienia się do łyżki",
    tip:
        "Spryskaj łyżkę odrobiną oleju przed nabraniem miodu — spłynie gładko, bez zostawiania połowy w łyżce.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Resztki wina nie muszą się zmarnować",
    tip:
        "Zamroź niedopite wino w kostkach lodu — świetnie sprawdzi się później jako baza do sosów czy duszonych potraw.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Drewniana łyżka a kipiący garnek",
    tip:
        "Łyżka położona w poprzek garnka nie jest pewnym zabezpieczeniem przed wykipieniem. Wybierz odpowiednio duży garnek, zmniejsz moc po zagotowaniu i obserwuj zawartość — to ważniejsze niż sam trik z łyżką.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Twaróg w sałatce zamiast mozzarelli",
    tip:
        "Pokrusz świeży twaróg lub pokrój go w małe kawałki i dodaj do sałatki. Będzie miał inną konsystencję i smak niż mozzarella, ale może być ciekawą alternatywą — nie trzeba go wcześniej płukać.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Ser żółty łatwiej zetrzesz zamrożony",
    tip:
        "Włóż kawałek żółtego sera na pół godziny do zamrażarki przed starciem — twardszy ser mniej się kruszy i nie zapycha tarki.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Śmietana bez zwarzenia w gorącej zupie",
    tip:
        "Dodaj do śmietany kilka łyżek ciepłej zupy i dokładnie wymieszaj, a następnie stopniowo wlewaj ją do garnka, mieszając. Zmniejsz ogień i unikaj gwałtownego zagotowania zupy po dodaniu śmietany.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Żółtka bez grudek w zupie",
    tip:
        "Jeśli przepis przewiduje dodanie żółtka do zupy, rozmieszaj je z odrobiną płynu i stopniowo połącz z ciepłą zupą, mieszając. Do potraw bez pełnego gotowania używaj jaj pasteryzowanych; samo zalanie surowego jajka gorącą zupą nie gwarantuje bezpiecznego podgrzania.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Zwiędła sałata odzyska jędrność",
    tip:
        "Lekko zwiędłe, ale nadal świeże liście zanurz na krótko w czystej, chłodnej wodzie, a potem dokładnie osusz. Nie trzeba dodawać mąki. Liści ze śladami pleśni lub zepsucia nie próbuj w ten sposób ratować.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Uparty słoik w końcu się otworzy",
    tip:
        "Osusz nakrętkę i dłonie, a następnie użyj gumowej rękawicy, antypoślizgowej podkładki albo chwytaka do słoików, aby poprawić uchwyt. Nie uderzaj szklanym słoikiem o blat — szkło może pęknąć lub się wyszczerbić.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Masło do ciasta kruchego? Zetrzyj je",
    tip:
        "Zamiast kroić zimne masło na kawałki do ciasta kruchego, zetrzyj je na tarce o grubych oczkach — szybciej i równiej połączy się z mąką, dając bardziej kruchą strukturę.",
    icon: IconIndex.baking,
  ),
  CookingTip(
    title: "Twarde masło zmięknie szybciej w kawałkach",
    tip:
        "Pokrój zimne masło w drobną kostkę lub cienkie plasterki i rozłóż na talerzu na czas przygotowywania pozostałych składników. Mniejsze kawałki miękną szybciej; nie trzeba przykrywać ich szklanką rozgrzaną wrzątkiem.",
    icon: IconIndex.baking,
  ),
  CookingTip(
    title: "Zaskakujący duet: truskawki i pieprz",
    tip:
        "Spróbuj dodać odrobinę świeżo mielonego czarnego pieprzu do kilku pokrojonych truskawek. Zacznij od małej ilości i sprawdź, czy odpowiada Ci kontrast smaków — pieprz nie usuwa cukru z owoców.",
    icon: IconIndex.general,
  ),
];

/// English content is compiled once; do not change order independently of PL.
const List<CookingTip> kCookingTipsEn = [
  CookingTip(
    title: "Pasta water is worth saving",
    tip:
        "Before draining pasta, save half a glass of the cooking water. Its starch helps the sauce cling to the pasta rather than collecting at the bottom of the plate.",
    icon: IconIndex.pasta,
  ),
  CookingTip(
    title: "Add salt for flavour",
    tip:
        "Salt pasta or potato water according to the recipe and stir to dissolve it. The salt seasons the food — an ordinary cooking quantity does not meaningfully speed up boiling.",
    icon: IconIndex.pasta,
  ),
  CookingTip(
    title: "Chill onions for fewer tears",
    tip:
        "Put an onion in the fridge for 15–20 minutes before chopping it. Chilling can help reduce the release of compounds that irritate your eyes.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Keep cut avocado from browning",
    tip:
        "Drizzle cut avocado with lemon or lime juice. The acidity slows oxidation and helps it keep its green colour for longer.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Separate rice grains start with rinsing",
    tip:
        "Rinse rice under cold water until the water runs clear. This removes excess surface starch, helping the grains stick together less.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Prepare meat just before cooking",
    tip:
        "Keep raw meat in the fridge until you start preparing it. Pieces of a similar thickness are easier to cook evenly; there is no need to leave them on the worktop to reach room temperature.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Make boiled eggs easier to peel",
    tip:
        "Put hard-boiled eggs into cold water for a few minutes straight after cooking. Cooling helps separate the shell from the white.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Treat fresh herbs like a bouquet",
    tip:
        "Keep parsley or dill in a glass with a little water in the fridge, like flowers in a vase. This can help them keep longer than in a plastic bag.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Get more juice from citrus fruit",
    tip:
        "Before squeezing a lemon or lime, roll it firmly under your palm on the worktop. This helps release more juice.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Do not overcrowd the pan",
    tip:
        "Too many ingredients at once lower the pan temperature. Vegetables or meat may start steaming in their juices rather than frying. Cook in batches instead.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Keep your kitchen knife sharp",
    tip:
        "A blunt knife needs more force and can slip. Keep your knife sharp and use it carefully on a stable chopping board.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Freeze herbs in olive oil",
    tip:
        "Chop fresh herbs, cover them with olive oil in an ice-cube tray and freeze. The cubes make a convenient starting point for sauces and stews in the coming weeks.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Revive stale bread",
    tip:
        "Sprinkle a little water over stale bread or a roll and warm it in the oven for a few minutes. The inside softens and the crust becomes crisp again.",
    icon: IconIndex.baking,
  ),
  CookingTip(
    title: "Rescue an overly salty sauce",
    tip:
        "Add small amounts of unsalted stock, water or other suitable unsalted ingredients, tasting after each change. A potato absorbs liquid as well as salt; it does not selectively remove salt and is not a reliable way to fix the seasoning.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Use acidity in a meat marinade",
    tip:
        "A little lemon juice, vinegar or yoghurt in a marinade can help tenderise meat. Follow the recipe for the amount and marinating time.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Heat your pan according to its instructions",
    tip:
        "The right preheating method depends on the pan. For non-stick cookware, follow the manufacturer's instructions and do not overheat an empty pan. Add fat if the recipe needs it and do not let it smoke.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Store potatoes away from onions",
    tip:
        "Keep potatoes and onions separately in suitable cool, dark storage. Storing them together can encourage sprouting and spoilage.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Keep green vegetables bright",
    tip:
        "Cook broccoli or green beans briefly in salted boiling water, then cool them promptly in cold water. This stops the cooking and helps preserve their colour.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Keep honey from sticking to the spoon",
    tip:
        "Lightly coat a spoon with a little oil before measuring honey. It will slide off more easily instead of leaving so much on the spoon.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Save leftover wine for cooking",
    tip:
        "Freeze leftover wine in an ice-cube tray. The cubes can be added later to sauces and stews.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "A wooden spoon and an overflowing pan",
    tip:
        "A spoon laid across a pan is not reliable protection against boiling over. Use a suitably large pan, reduce the heat after boiling and keep an eye on the contents — these matter more than the spoon trick.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Try Polish curd cheese in a salad",
    tip:
        "Crumble fresh twaróg or cut it into small pieces and add it to a salad. Its texture and flavour differ from mozzarella, but it can make an interesting alternative. There is no need to rinse it first.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Chill cheese before grating",
    tip:
        "Put a piece of hard cheese in the freezer for half an hour before grating. Firmer cheese is easier to grate without clogging the grater.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Add sour cream without curdling the soup",
    tip:
        "Stir a few spoonfuls of warm soup into the sour cream first. Gradually stir this mixture into the pan. Lower the heat and avoid bringing the soup to a vigorous boil after adding the cream.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Add egg yolks smoothly to soup",
    tip:
        "If the recipe calls for egg yolk, mix it with a little liquid and gradually stir it into warm soup. Use pasteurised eggs for dishes that will not be fully cooked. Pouring hot soup over a raw egg does not guarantee safe heating.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Refresh slightly wilted lettuce",
    tip:
        "Briefly soak slightly wilted but still fresh leaves in clean, cool water, then dry them well. There is no need to add flour. Do not try to rescue mouldy or spoiled leaves this way.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Get a stubborn jar open",
    tip:
        "Dry the lid and your hands, then use a rubber glove, non-slip mat or jar opener to improve your grip. Do not bang a glass jar against the worktop: the glass can crack or chip.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Grate butter for shortcrust pastry",
    tip:
        "Instead of cutting cold butter into chunks, coarsely grate it for shortcrust pastry. It will mix with the flour more quickly and evenly.",
    icon: IconIndex.baking,
  ),
  CookingTip(
    title: "Small pieces of butter soften faster",
    tip:
        "Cut cold butter into small cubes or thin slices and spread them on a plate while you prepare the other ingredients. Smaller pieces soften faster; there is no need to cover them with a glass heated with boiling water.",
    icon: IconIndex.baking,
  ),
  CookingTip(
    title: "Strawberries with a twist of pepper",
    tip:
        "Try a little freshly ground black pepper on a few sliced strawberries. Start with a small amount and see whether you enjoy the contrasting flavours. Pepper does not remove sugar from the fruit.",
    icon: IconIndex.general,
  ),
];

const List<CookingTip> kCookingTipsDe = [
  CookingTip(
    title: "Nudelwasser aufheben",
    tip:
        "Heb vor dem Abgießen der Nudeln ein halbes Glas Kochwasser auf. Die Stärke darin hilft, die Soße an den Nudeln zu binden.",
    icon: IconIndex.pasta,
  ),
  CookingTip(
    title: "Salz gibt Geschmack",
    tip:
        "Salze das Wasser für Nudeln oder Kartoffeln nach Rezept und rühre um, bis sich das Salz auflöst. Es würzt das Essen. Die übliche Menge lässt Wasser kaum schneller kochen.",
    icon: IconIndex.pasta,
  ),
  CookingTip(
    title: "Gekühlte Zwiebeln schneiden",
    tip:
        "Leg die Zwiebel vor dem Schneiden für 15–20 Minuten in den Kühlschrank. Die Kälte kann dafür sorgen, dass weniger reizende Stoffe freigesetzt werden.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Avocado frisch halten",
    tip:
        "Beträufle die Schnittfläche mit Zitronen- oder Limettensaft. Die Säure verlangsamt die Oxidation, sodass die Avocado länger grün bleibt.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Reis vorher abspülen",
    tip:
        "Spüle den Reis mit kaltem Wasser ab, bis das Wasser klar bleibt. Das entfernt überschüssige Stärke, sodass die Körner weniger aneinanderkleben.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Fleisch erst kurz vor dem Garen vorbereiten",
    tip:
        "Lass rohes Fleisch bis zur Vorbereitung im Kühlschrank. Gleich dicke Stücke garen gleichmäßiger. Sie brauchen vorher keine Zimmertemperatur anzunehmen.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Gekochte Eier leichter schälen",
    tip:
        "Leg hart gekochte Eier direkt nach dem Kochen für ein paar Minuten in kaltes Wasser. Durch das Abkühlen kann sich die Schale leichter vom Eiweiß lösen.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Kräuter wie einen Blumenstrauß lagern",
    tip:
        "Stell Petersilie oder Dill mit etwas Wasser in ein Glas und bewahre sie im Kühlschrank auf. So können sie länger frisch bleiben als in einer Plastiktüte.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Mehr Saft aus Zitronen und Limetten",
    tip:
        "Rolle die Frucht vor dem Auspressen mit leichtem Druck unter deiner Handfläche über die Arbeitsplatte. So lässt sich mehr Saft gewinnen.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "In kleinen Mengen anbraten",
    tip:
        "Zu viele Zutaten auf einmal kühlen die Pfanne ab. Gemüse oder Fleisch kann im eigenen Saft dünsten. Brate es portionsweise an.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Küchenmesser scharf halten",
    tip:
        "Ein stumpfes Messer erfordert mehr Kraft und rutscht leichter ab. Halte das Messer scharf und schneide vorsichtig auf einem stabilen Brett.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Kräuter in Olivenöl einfrieren",
    tip:
        "Gib gehackte Kräuter mit Olivenöl in eine Eiswürfelform und friere sie ein. Die Würfel eignen sich in den nächsten Wochen als Basis für Soßen und Eintöpfe.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Brot wieder knusprig machen",
    tip:
        "Besprenkle trockenes Brot oder Brötchen mit etwas Wasser und wärme es ein paar Minuten im Ofen auf. Die Krume wird weicher und die Kruste wieder knusprig.",
    icon: IconIndex.baking,
  ),
  CookingTip(
    title: "Versalzene Soße retten",
    tip:
        "Gib nach und nach ungesalzene Brühe, Wasser oder andere passende ungesalzene Zutaten hinzu und schmecke zwischendurch ab. Eine Kartoffel nimmt Flüssigkeit samt Salz auf und ist daher kein verlässliches Mittel gegen zu viel Salz.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Säure in der Marinade",
    tip:
        "Etwas Zitronensaft, Essig oder Joghurt in der Marinade kann Fleisch zarter machen. Halte dich bei Menge und Dauer ans Rezept.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Pfanne richtig vorheizen",
    tip:
        "Wie du eine Pfanne vorheizt, hängt vom Material ab. Beachte bei beschichteten Pfannen die Herstellerangaben und überhitze sie nicht leer. Lass Bratfett nicht rauchen.",
    icon: IconIndex.meat,
  ),
  CookingTip(
    title: "Kartoffeln und Zwiebeln getrennt lagern",
    tip:
        "Bewahre Kartoffeln und Zwiebeln getrennt an geeigneten kühlen, dunklen Orten auf. Zusammen können sie schneller keimen und verderben.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Grünes Gemüse behält seine Farbe",
    tip:
        "Koche Brokkoli oder grüne Bohnen kurz in sprudelndem Salzwasser und kühle das Gemüse danach zügig mit kaltem Wasser ab. Das stoppt den Garvorgang und hilft, die Farbe zu erhalten.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Honig leichter vom Löffel lösen",
    tip:
        "Bestreiche den Löffel vor dem Abmessen mit einem Hauch Öl. Dann gleitet der Honig leichter vom Löffel.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Weinreste zum Kochen aufheben",
    tip:
        "Friere übrig gebliebenen Wein in einer Eiswürfelform ein. Die Würfel kannst du später in Soßen und Eintöpfe geben.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Überkochen im Topf vermeiden",
    tip:
        "Ein Kochlöffel quer über dem Topf verhindert das Überkochen nicht zuverlässig. Verwende einen ausreichend großen Topf, reduziere nach dem Aufkochen die Hitze und behalte den Inhalt im Blick.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Polnischen Frischkäse im Salat probieren",
    tip:
        "Zerbrösele frischen Twaróg oder schneide ihn in kleine Stücke und gib ihn in den Salat. Er schmeckt anders als Mozzarella und hat eine andere Konsistenz. Abspülen ist überflüssig.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Käse vor dem Reiben kühlen",
    tip:
        "Leg Hartkäse vor dem Reiben eine halbe Stunde ins Gefrierfach. Fester Käse lässt sich leichter reiben und bleibt weniger an der Reibe hängen.",
    icon: IconIndex.storage,
  ),
  CookingTip(
    title: "Saure Sahne in die Suppe rühren",
    tip:
        "Rühre zuerst ein paar Löffel warme Suppe unter die saure Sahne und gib die Mischung dann nach und nach in den Topf. Reduziere die Hitze und lass die Suppe danach nicht mehr sprudelnd kochen.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Eigelb gleichmäßig in die Suppe rühren",
    tip:
        "Wenn das Rezept Eigelb vorsieht, verrühre es mit etwas Flüssigkeit und gib es nach und nach in die warme Suppe. Verwende pasteurisierte Eier für Gerichte, die nicht vollständig durchgegart werden. Heiße Suppe allein erhitzt ein rohes Ei nicht zuverlässig.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Leicht welken Salat auffrischen",
    tip:
        "Leg leicht welke, noch frische Blätter kurz in sauberes, kühles Wasser und trockne sie gut ab. Mehl brauchst du dafür nicht. Schimmelige oder verdorbene Blätter gehören entsorgt.",
    icon: IconIndex.vegetable,
  ),
  CookingTip(
    title: "Ein festsitzendes Glas öffnen",
    tip:
        "Trockne Deckel und Hände ab. Ein Gummihandschuh, eine rutschfeste Unterlage oder ein Glasöffner geben dir mehr Halt. Schlag das Glas nicht auf die Arbeitsplatte, da es reißen oder splittern kann.",
    icon: IconIndex.general,
  ),
  CookingTip(
    title: "Butter für Mürbeteig reiben",
    tip:
        "Reibe kalte Butter grob, statt sie in Stücke zu schneiden. So vermischt sie sich für den Mürbeteig schneller und gleichmäßiger mit dem Mehl.",
    icon: IconIndex.baking,
  ),
  CookingTip(
    title: "Kleine Butterstücke werden schneller weich",
    tip:
        "Schneide kalte Butter in Würfel oder dünne Scheiben und verteile sie auf einem Teller. Kleine Stücke werden von selbst schneller weich.",
    icon: IconIndex.baking,
  ),
  CookingTip(
    title: "Erdbeeren mit einer Prise Pfeffer",
    tip:
        "Streu eine kleine Menge frisch gemahlenen schwarzen Pfeffer auf ein paar geschnittene Erdbeeren und probiere, ob dir der Kontrast schmeckt.",
    icon: IconIndex.general,
  ),
];
