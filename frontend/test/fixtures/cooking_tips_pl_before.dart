/// Snapshot before owner-approved content corrections in stage 20.
const cookingTipsPlBefore = <Map<String, String>>[
  {
    "title": "Woda z makaronu to złoto",
    "tip":
        "Zanim odcedzisz makaron, zachowaj pół szklanki wody z gotowania. Skrobia w niej zawarta pomaga sosowi lepiej \"chwycić się\" makaronu zamiast spływać na dno talerza.",
    "icon": "pasta",
  },
  {
    "title": "Sól dodawaj, gdy woda już wrze",
    "tip":
        "Solenie wody na makaron czy ziemniaki PO zagotowaniu, nie przed, sprawia, że woda szybciej wraca do wrzenia i sól równomiernie się rozpuszcza.",
    "icon": "pasta",
  },
  {
    "title": "Zimna cebula to mniej łez",
    "tip":
        "Schłodzenie cebuli w lodówce przez 15-20 minut przed krojeniem znacząco ogranicza uwalnianie substancji drażniącej oczy.",
    "icon": "vegetable",
  },
  {
    "title": "Awokado bez brązowienia",
    "tip":
        "Skrop przekrojone awokado sokiem z cytryny lub limonki — kwas spowalnia utlenianie i dłużej zachowuje zielony kolor.",
    "icon": "vegetable",
  },
  {
    "title": "Sypki ryż zaczyna się przed gotowaniem",
    "tip":
        "Opłucz ryż pod zimną wodą, aż woda przestanie być mętna — usuwa to nadmiar skrobi z powierzchni ziaren, dzięki czemu ziarna mniej się sklejają.",
    "icon": "general",
  },
  {
    "title": "Mięso lubi pokojową temperaturę",
    "tip":
        "Wyjmij mięso z lodówki 20-30 minut przed smażeniem czy grillowaniem — usmaży się równomierniej, bez zimnego środka przy przypieczonym brzegu.",
    "icon": "meat",
  },
  {
    "title": "Łatwiejsze obieranie jajek",
    "tip":
        "Zaraz po ugotowaniu na twardo wrzuć jajka do zimnej wody na kilka minut. Nagła zmiana temperatury ułatwia oddzielenie skorupki od białka.",
    "icon": "general",
  },
  {
    "title": "Świeże zioła jak bukiet kwiatów",
    "tip":
        "Pietruszkę, koperek czy natkę trzymaj w szklance z odrobiną wody w lodówce, jak kwiaty w wazonie — wytrzymają znacznie dłużej niż w foliowej torebce.",
    "icon": "storage",
  },
  {
    "title": "Więcej soku z cytrusów",
    "tip":
        "Przed wyciśnięciem przetocz cytrynę czy limonkę mocno dłonią po blacie — rozbija to komórki wewnątrz i pozwala wycisnąć zauważalnie więcej soku.",
    "icon": "general",
  },
  {
    "title": "Nie przepełniaj patelni",
    "tip":
        "Zbyt duża ilość składników naraz obniża temperaturę patelni — zamiast się smażyć, warzywa czy mięso zaczynają się dusić we własnym soku. Lepiej smażyć partiami.",
    "icon": "meat",
  },
  {
    "title": "Ostry nóż jest bezpieczniejszy",
    "tip":
        "Tępy nóż wymaga więcej siły i częściej się ześlizguje — to on, nie ostry, jest częstszą przyczyną skaleczeń w kuchni.",
    "icon": "general",
  },
  {
    "title": "Zamrażaj zioła w oliwie",
    "tip":
        "Posiekane świeże zioła zalane oliwą i zamrożone w kostkach lodu to gotowa baza do sosów i duszenia na kolejne tygodnie.",
    "icon": "storage",
  },
  {
    "title": "Czerstwy chleb wraca do życia",
    "tip":
        "Skrop czerstwą bułkę czy chleb odrobiną wody i podgrzej kilka minut w piekarniku — para wodna przywraca miękkość na środku, a skórka znów robi się chrupiąca.",
    "icon": "baking",
  },
  {
    "title": "Ratunek dla zbyt słonego sosu",
    "tip":
        "Dodaj do gotującego się sosu obrany kawałek surowego ziemniaka na kilka minut, a potem go wyjmij — wchłonie część nadmiaru soli.",
    "icon": "general",
  },
  {
    "title": "Kwas zmiękcza mięso",
    "tip":
        "Odrobina soku z cytryny, octu albo jogurtu w marynacie pomaga rozluźnić włókna mięsa, dzięki czemu po usmażeniu jest bardziej kruche.",
    "icon": "meat",
  },
  {
    "title": "Najpierw patelnia, potem tłuszcz",
    "tip":
        "Rozgrzej suchą patelnię, dopiero potem dodaj olej czy masło — tłuszcz szybciej osiągnie właściwą temperaturę i składniki się nie przykleją.",
    "icon": "meat",
  },
  {
    "title": "Ziemniaki z dala od cebuli",
    "tip":
        "Przechowywane razem przyspieszają sobie nawzajem kiełkowanie i psucie się — trzymaj je w oddzielnych, ciemnych miejscach.",
    "icon": "storage",
  },
  {
    "title": "Zielone warzywa zostają zielone",
    "tip":
        "Krótko gotuj brokuły czy fasolkę w osolonym wrzątku, a zaraz potem przelej zimną wodą — zatrzymuje to proces gotowania i zachowuje intensywny kolor.",
    "icon": "vegetable",
  },
  {
    "title": "Miód bez lepienia się do łyżki",
    "tip":
        "Spryskaj łyżkę odrobiną oleju przed nabraniem miodu — spłynie gładko, bez zostawiania połowy w łyżce.",
    "icon": "general",
  },
  {
    "title": "Resztki wina nie muszą się zmarnować",
    "tip":
        "Zamroź niedopite wino w kostkach lodu — świetnie sprawdzi się później jako baza do sosów czy duszonych potraw.",
    "icon": "storage",
  },
  {
    "title": "Drewniana łyżka ratuje przed wykipieniem",
    "tip":
        "Połóż drewnianą łyżkę w poprzek garnka z gotującą się wodą lub mlekiem. Pękanie piany o drewno zapobiega jej gwałtownemu wykipieniu — prostsze niż pilnowanie garnka co chwilę.",
    "icon": "general",
  },
  {
    "title": "Twaróg jak mini-mozzarella",
    "tip":
        "Przepłucz zwykły twaróg pod bieżącą zimną wodą i odsącz na sicie. Zamiast gładkiej pasty zostają delikatne, wilgotne grudki — świetne do sałatek zamiast klasycznej mozzarelli.",
    "icon": "general",
  },
  {
    "title": "Ser żółty łatwiej zetrzesz zamrożony",
    "tip":
        "Włóż kawałek żółtego sera na pół godziny do zamrażarki przed starciem — twardszy ser mniej się kruszy i nie zapycha tarki.",
    "icon": "storage",
  },
  {
    "title": "Śmietana bez zwarzenia w gorącej zupie",
    "tip":
        "Zanim dodasz śmietanę do gorącej zupy, wymieszaj ją wcześniej z kilkoma łyżkami zimnego mleka. Stopniowe wyrównanie temperatury zapobiega jej zwarzeniu się w kontakcie z gorącym płynem.",
    "icon": "general",
  },
  {
    "title": "Żółtka bez grudek w zupie",
    "tip":
        "Surowe żółtko lekko ubij z odrobiną wody lub mleka, zanim dodasz je do gorącej zupy na zabielenie — inaczej zetnie się w mało apetyczne strzępki.",
    "icon": "general",
  },
  {
    "title": "Zwiędła sałata odzyska świeżość",
    "tip":
        "Włóż sałatę czy zioła na kilka minut do miski zimnej wody z łyżeczką mąki ziemniaczanej — liście znów staną się jędrne i chrupiące.",
    "icon": "vegetable",
  },
  {
    "title": "Uparty słoik w końcu się otworzy",
    "tip":
        "Kilka mocnych uderzeń denkiem słoika o krawędź blatu (nie samym wieczkiem) rozluźnia próżnię i sprawia, że nakrętka odkręca się znacznie łatwiej.",
    "icon": "general",
  },
  {
    "title": "Masło do ciasta kruchego? Zetrzyj je",
    "tip":
        "Zamiast kroić zimne masło na kawałki do ciasta kruchego, zetrzyj je na tarce o grubych oczkach — szybciej i równiej połączy się z mąką, dając bardziej kruchą strukturę.",
    "icon": "baking",
  },
  {
    "title": "Twarde masło miękkie w minutę",
    "tip":
        "Przykryj kostkę masła prosto z lodówki podgrzaną (np. wodą z czajnika) szklanką na około minutę — ciepłe powietrze wewnątrz szybko je zmiękczy, bez rozpuszczania.",
    "icon": "baking",
  },
  {
    "title": "Zaskakujący duet: truskawki i pieprz",
    "tip":
        "Odrobina świeżo mielonego czarnego pieprzu na pokrojonych truskawkach nie \"psuje\" smaku — pieprzowa ostrość neutralizuje mdłą słodycz i wydobywa głębszy aromat owoców.",
    "icon": "general",
  },
];
