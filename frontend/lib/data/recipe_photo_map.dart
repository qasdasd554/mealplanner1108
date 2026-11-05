/// Mapowanie 167 oficjalnych przepisów -> lokalne zdjęcie dania.
/// Przepisy użytkowników nie korzystają z tej mapy, nawet gdy mają taką
/// samą nazwę; dla nich źródłem jest przesłane zdjęcie albo ilustracja
/// kategorii.
const Map<String, String> kRecipePhotoAssets = {
  'Jabłko z masłem orzechowym':
      'assets/recipe_photos/01-jablko-z-maslem-orzechowym.jpg',
  'Marchewki z hummusem': 'assets/recipe_photos/02-marchewki-z-hummusem.jpg',
  'Jogurt naturalny z malinami':
      'assets/recipe_photos/03-jogurt-naturalny-z-malinami.jpg',
  'Owsianka na mleku migdałowym':
      'assets/recipe_photos/04-owsianka-na-mleku-migdalowym.jpg',
  'Sałatka grecka': 'assets/recipe_photos/05-salatka-grecka.jpg',
  'Jajecznica z pomidorami':
      'assets/recipe_photos/06-jajecznica-z-pomidorami.jpg',
  'Kanapki z szynką i serem':
      'assets/recipe_photos/07-kanapki-z-szynka-i-serem.jpg',
  'Owsianka z jogurtem': 'assets/recipe_photos/08-owsianka-z-jogurtem.jpg',
  'Kotlet schabowy z ziemniakami':
      'assets/recipe_photos/09-kotlet-schabowy-z-ziemniakami.jpg',
  'Spaghetti bolognese': 'assets/recipe_photos/10-spaghetti-bolognese.jpg',
  'Kurczak z ryżem i warzywami':
      'assets/recipe_photos/11-kurczak-z-ryzem-i-warzywami.jpg',
  'Zupa pomidorowa z makaronem':
      'assets/recipe_photos/12-zupa-pomidorowa-z-makaronem.jpg',
  'Sałatka z łososiem': 'assets/recipe_photos/13-salatka-z-lososiem.jpg',
  'Naleśniki z serem': 'assets/recipe_photos/14-nalesniki-z-serem.jpg',
  'Tosty z jajkiem i awokado':
      'assets/recipe_photos/15-tosty-z-jajkiem-i-awokado.jpg',
  'Shakshuka': 'assets/recipe_photos/16-shakshuka.jpg',
  'Pad Thai z kurczakiem': 'assets/recipe_photos/17-pad-thai-z-kurczakiem.jpg',
  'Bowl z quinoa i awokado':
      'assets/recipe_photos/18-bowl-z-quinoa-i-awokado.jpg',
  'Risotto z grzybami leśnymi':
      'assets/recipe_photos/19-risotto-z-grzybami-lesnymi.jpg',
  'Overnight oats z chia i owocami':
      'assets/recipe_photos/20-overnight-oats-z-chia-i-owocami.jpg',
  'Jajka na twardo z awokado i tostem':
      'assets/recipe_photos/21-jajka-na-twardo-z-awokado-i-tostem.jpg',
  'Granola owsiana z miodem i orzechami':
      'assets/recipe_photos/22-granola-owsiana-z-miodem-i-orzechami.jpg',
  'Kanapki z pastą jajeczną':
      'assets/recipe_photos/23-kanapki-z-pasta-jajeczna.jpg',
  'Placki jaglane na słodko':
      'assets/recipe_photos/24-placki-jaglane-na-slodko.jpg',
  'Omlet z warzywami': 'assets/recipe_photos/25-omlet-z-warzywami.jpg',
  'Musli z mlekiem kokosowym i mango':
      'assets/recipe_photos/26-musli-z-mlekiem-kokosowym-i-mango.jpg',
  'Tost francuski z cynamonem':
      'assets/recipe_photos/27-tost-francuski-z-cynamonem.jpg',
  'Smoothie bowl bananowo-truskawkowe':
      'assets/recipe_photos/28-smoothie-bowl-bananowo-truskawkowe.jpg',
  'Kanapka z hummusem i warzywami':
      'assets/recipe_photos/29-kanapka-z-hummusem-i-warzywami.jpg',
  'Owsianka z masłem orzechowym i bananem':
      'assets/recipe_photos/30-owsianka-z-maslem-orzechowym-i-bananem.jpg',
  'Jajka sadzone z pomidorami i bazylią':
      'assets/recipe_photos/31-jajka-sadzone-z-pomidorami-i-bazylia.jpg',
  'Naleśniki jaglane z owocami':
      'assets/recipe_photos/32-nalesniki-jaglane-z-owocami.jpg',
  'Makaron z brokułami i parmezanem':
      'assets/recipe_photos/33-makaron-z-brokulami-i-parmezanem.jpg',
  'Krem z brokułów': 'assets/recipe_photos/34-krem-z-brokulow.jpg',
  'Krem z kalafiora': 'assets/recipe_photos/35-krem-z-kalafiora.jpg',
  'Zupa krem z pieczarek': 'assets/recipe_photos/36-zupa-krem-z-pieczarek.jpg',
  'Zupa jarzynowa z porem':
      'assets/recipe_photos/37-zupa-jarzynowa-z-porem.jpg',
  'Kurczak curry z ryżem': 'assets/recipe_photos/38-kurczak-curry-z-ryzem.jpg',
  'Gulasz wołowo-wieprzowy':
      'assets/recipe_photos/39-gulasz-wolowo-wieprzowy.jpg',
  'Chili con carne': 'assets/recipe_photos/40-chili-con-carne.jpg',
  'Tacos z indykiem': 'assets/recipe_photos/41-tacos-z-indykiem.jpg',
  'Burrito bowl z kurczakiem':
      'assets/recipe_photos/42-burrito-bowl-z-kurczakiem.jpg',
  'Makaron z tuńczykiem i pomidorami':
      'assets/recipe_photos/43-makaron-z-tunczykiem-i-pomidorami.jpg',
  'Sałatka z kurczakiem i awokado':
      'assets/recipe_photos/44-salatka-z-kurczakiem-i-awokado.jpg',
  'Sałatka z ciecierzycą i fetą':
      'assets/recipe_photos/45-salatka-z-ciecierzyca-i-feta.jpg',
  'Soczewica po indyjsku (dal)':
      'assets/recipe_photos/46-soczewica-po-indyjsku-dal.jpg',
  'Kotlety mielone z indyka':
      'assets/recipe_photos/47-kotlety-mielone-z-indyka.jpg',
  'Kurczak pieczony z warzywami':
      'assets/recipe_photos/48-kurczak-pieczony-z-warzywami.jpg',
  'Dorsz pieczony z cytryną i ziołami':
      'assets/recipe_photos/49-dorsz-pieczony-z-cytryna-i-ziolami.jpg',
  'Krewetki curry z ryżem':
      'assets/recipe_photos/50-krewetki-curry-z-ryzem.jpg',
  'Placki ziemniaczane': 'assets/recipe_photos/51-placki-ziemniaczane.jpg',
  'Bigos szybki': 'assets/recipe_photos/52-bigos-szybki.jpg',
  'Pierogi leniwe': 'assets/recipe_photos/53-pierogi-leniwe.jpg',
  'Kotlety schabowe z kapustą pekińską':
      'assets/recipe_photos/54-kotlety-schabowe-z-kapusta-pekinska.jpg',
  'Makaron z cukinią i parmezanem':
      'assets/recipe_photos/55-makaron-z-cukinia-i-parmezanem.jpg',
  'Risotto z krewetkami': 'assets/recipe_photos/56-risotto-z-krewetkami.jpg',
  'Kasza gryczana z pieczarkami i cebulą':
      'assets/recipe_photos/57-kasza-gryczana-z-pieczarkami-i-cebula.jpg',
  'Zapiekanka z cukinii i sera':
      'assets/recipe_photos/58-zapiekanka-z-cukinii-i-sera.jpg',
  'Bakłażan zapiekany po grecku':
      'assets/recipe_photos/59-baklazan-zapiekany-po-grecku.jpg',
  'Sałatka z tuńczykiem i jajkiem':
      'assets/recipe_photos/60-salatka-z-tunczykiem-i-jajkiem.jpg',
  'Kanapki caprese': 'assets/recipe_photos/61-kanapki-caprese.jpg',
  'Sałatka caprese': 'assets/recipe_photos/62-salatka-caprese.jpg',
  'Omlet na słono z serem i szczypiorkiem':
      'assets/recipe_photos/63-omlet-na-slono-z-serem-i-szczypiorkiem.jpg',
  'Tost z hummusem i warzywami':
      'assets/recipe_photos/64-tost-z-hummusem-i-warzywami.jpg',
  'Sałatka z soczewicy i fety':
      'assets/recipe_photos/65-salatka-z-soczewicy-i-fety.jpg',
  'Wrap z kurczakiem i warzywami':
      'assets/recipe_photos/66-wrap-z-kurczakiem-i-warzywami.jpg',
  'Quesadilla z serem': 'assets/recipe_photos/67-quesadilla-z-serem.jpg',
  'Zupa krem z brokuła i sera':
      'assets/recipe_photos/68-zupa-krem-z-brokula-i-sera.jpg',
  'Kanapki z pastą z ciecierzycy':
      'assets/recipe_photos/69-kanapki-z-pasta-z-ciecierzycy.jpg',
  'Sałatka grecka z krewetkami':
      'assets/recipe_photos/70-salatka-grecka-z-krewetkami.jpg',
  'Zupa krem porowa': 'assets/recipe_photos/71-zupa-krem-porowa.jpg',
  'Tosty z pastą jajeczną i szczypiorkiem':
      'assets/recipe_photos/72-tosty-z-pasta-jajeczna-i-szczypiorkiem.jpg',
  'Sałatka z awokado i jajkiem':
      'assets/recipe_photos/73-salatka-z-awokado-i-jajkiem.jpg',
  'Pieczone chipsy z kalafiora':
      'assets/recipe_photos/74-pieczone-chipsy-z-kalafiora.jpg',
  'Kulki mocy owsiano-orzechowe':
      'assets/recipe_photos/75-kulki-mocy-owsiano-orzechowe.jpg',
  'Pieczona chrupiąca ciecierzyca':
      'assets/recipe_photos/76-pieczona-chrupiaca-ciecierzyca.jpg',
  'Smoothie mango-bananowe':
      'assets/recipe_photos/77-smoothie-mango-bananowe.jpg',
  'Jogurt z granolą i miodem':
      'assets/recipe_photos/78-jogurt-z-granola-i-miodem.jpg',
  'Sałatka owocowa': 'assets/recipe_photos/79-salatka-owocowa.jpg',
  'Guacamole z warzywami': 'assets/recipe_photos/80-guacamole-z-warzywami.jpg',
  'Musli batoniki owsiane':
      'assets/recipe_photos/81-musli-batoniki-owsiane.jpg',
  'Makaron z cukinią i tuńczykiem':
      'assets/recipe_photos/082-makaron-z-cukinia-i-tunczykiem.jpg',
  'Pieczony dorsz z zielonym groszkiem':
      'assets/recipe_photos/083-pieczony-dorsz-z-zielonym-groszkiem.jpg',
  'Placki z twarogiem na słodko':
      'assets/recipe_photos/084-placki-z-twarogiem-na-slodko.jpg',
  'Zupa krem z zielonego groszku':
      'assets/recipe_photos/085-zupa-krem-z-zielonego-groszku.jpg',
  'Stir-fry ryżowy z kurczakiem i warzywami':
      'assets/recipe_photos/086-stir-fry-ryzowy-z-kurczakiem-i-warzywami.jpg',
  'Owsianka z orzechami włoskimi na mleku migdałowym':
      'assets/recipe_photos/087-owsianka-z-orzechami-wloskimi-na-mleku-migdalowym.jpg',
  'Fit burger z kurczaka': 'assets/recipe_photos/088-fit-burger-z-kurczaka.jpg',
  'Sałatka cezar z kurczakiem':
      'assets/recipe_photos/089-salatka-cezar-z-kurczakiem.jpg',
  'Omlet bananowy na słodko':
      'assets/recipe_photos/090-omlet-bananowy-na-slodko.jpg',
  'Owsianka na noc z chia i owocami':
      'assets/recipe_photos/091-owsianka-na-noc-z-chia-i-owocami.jpg',
  'Sałatka z wędzonym łososiem, mango i awokado':
      'assets/recipe_photos/092-salatka-z-wedzonym-lososiem-mango-i-awokado.jpg',
  'Makaron z brokułem w sosie śmietanowym':
      'assets/recipe_photos/093-makaron-z-brokulem-w-sosie-smietanowym.jpg',
  'Tost z awokado i mozzarellą':
      'assets/recipe_photos/094-tost-z-awokado-i-mozzarella.jpg',
  'Granola na słono z jajkiem i pomidorkami':
      'assets/recipe_photos/095-granola-na-slono-z-jajkiem-i-pomidorkami.jpg',
  'Dorsz na parze z warzywami i ziemniakami':
      'assets/recipe_photos/096-dorsz-na-parze-z-warzywami-i-ziemniakami.jpg',
  'Kanapki z szynką, serem i sałatą':
      'assets/recipe_photos/097-kanapki-z-szynka-serem-i-salata.jpg',
  'Sałatka z makaronem, brokułem i wędzonym łososiem':
      'assets/recipe_photos/098-salatka-z-makaronem-brokulem-i-wedzonym-lososiem.jpg',
  'Szybka zupa curry z ciecierzycą':
      'assets/recipe_photos/099-szybka-zupa-curry-z-ciecierzyca.jpg',
  'Tost z awokado i pomidorem':
      'assets/recipe_photos/100-tost-z-awokado-i-pomidorem.jpg',
  'Curry z ciecierzycą i szpinakiem':
      'assets/recipe_photos/101-curry-z-ciecierzyca-i-szpinakiem.jpg',
  'Sałatka z ciecierzycą i awokado':
      'assets/recipe_photos/102-salatka-z-ciecierzyca-i-awokado.jpg',
  'Makaron z pomidorami i bazylią':
      'assets/recipe_photos/103-makaron-z-pomidorami-i-bazylia.jpg',
  'Kasza gryczana z warzywami':
      'assets/recipe_photos/104-kasza-gryczana-z-warzywami.jpg',
  'Awokado z jajkiem sadzonym':
      'assets/recipe_photos/105-awokado-z-jajkiem-sadzonym.jpg',
  'Kurczak z masłem ziołowym i brokułem':
      'assets/recipe_photos/106-kurczak-z-maslem-ziolowym-i-brokulem.jpg',
  'Jajka na twardo': 'assets/recipe_photos/107-jajka-na-twardo.jpg',
  'Oliwki z serem feta': 'assets/recipe_photos/108-oliwki-z-serem-feta.jpg',
  'Twaróg z miodem': 'assets/recipe_photos/109-twarog-z-miodem.jpg',
  'Szynka z serem': 'assets/recipe_photos/110-szynka-z-serem.jpg',
  'Jogurt z orzechami': 'assets/recipe_photos/111-jogurt-z-orzechami.jpg',
  'Sałatka z tuńczyka i ogórkiem':
      'assets/recipe_photos/112-salatka-z-tunczyka-i-ogorkiem.jpg',
  'Mandarynkowe skrzydełka z airfryera':
      'assets/recipe_photos/113-mandarynkowe-skrzydelka-z-airfryera.jpg',
  'Łosoś teriyaki z fasolką z airfryera':
      'assets/recipe_photos/114-losos-teriyaki-z-fasolka-z-airfryera.jpg',
  'Paluszki z dorsza w panko z airfryera':
      'assets/recipe_photos/115-paluszki-z-dorsza-w-panko-z-airfryera.jpg',
  'Krewetki kokosowe z airfryera':
      'assets/recipe_photos/116-krewetki-kokosowe-z-airfryera.jpg',
  'Polędwiczka w musztardzie francuskiej z airfryera':
      'assets/recipe_photos/117-poledwiczka-w-musztardzie-francuskiej-z-airfryera.jpg',
  'Kofty z indyka z miętowym skyrem':
      'assets/recipe_photos/118-kofty-z-indyka-z-mietowym-skyrem.jpg',
  'Chrupiące tofu w sosie pomarańczowym':
      'assets/recipe_photos/119-chrupiace-tofu-w-sosie-pomaranczowym.jpg',
  'Falafel z airfryera z sosem tahini':
      'assets/recipe_photos/120-falafel-z-airfryera-z-sosem-tahini.jpg',
  'Frytki z halloumi z dipem granatowym':
      'assets/recipe_photos/121-frytki-z-halloumi-z-dipem-granatowym.jpg',
  'Arancini z mozzarellą z airfryera':
      'assets/recipe_photos/122-arancini-z-mozzarella-z-airfryera.jpg',
  'Chrupiące gnocchi z pesto rosso':
      'assets/recipe_photos/123-chrupiace-gnocchi-z-pesto-rosso.jpg',
  'Portobello ze szpinakiem i ricottą':
      'assets/recipe_photos/124-portobello-ze-szpinakiem-i-ricotta.jpg',
  'Mini calzone z salami i żółtą papryką':
      'assets/recipe_photos/125-mini-calzone-z-salami-i-zolta-papryka.jpg',
  'Placki z cukinii i pecorino z airfryera':
      'assets/recipe_photos/126-placki-z-cukinii-i-pecorino-z-airfryera.jpg',
  'Bataty hasselback z fetą i harissą':
      'assets/recipe_photos/127-bataty-hasselback-z-feta-i-harissa.jpg',
  'Brukselka balsamiczna z orzechami pekan':
      'assets/recipe_photos/128-brukselka-balsamiczna-z-orzechami-pekan.jpg',
  'Marchewkowe frytki zaatar z hummusem':
      'assets/recipe_photos/129-marchewkowe-frytki-zaatar-z-hummusem.jpg',
  'Frytki z polenty z sosem marinara':
      'assets/recipe_photos/130-frytki-z-polenty-z-sosem-marinara.jpg',
  'Brokułowe kąski z cheddarem':
      'assets/recipe_photos/131-brokulowe-kaski-z-cheddarem.jpg',
  'Wędzona kukurydza z limonką z airfryera':
      'assets/recipe_photos/132-wedzona-kukurydza-z-limonka-z-airfryera.jpg',
  'Jabłkowe crumble z airfryera':
      'assets/recipe_photos/133-jablkowe-crumble-z-airfryera.jpg',
  'Gruszki z serem pleśniowym i pekanami':
      'assets/recipe_photos/134-gruszki-z-serem-plesniowym-i-pekanami.jpg',
  'Pomarańczowe serniczki ze skyru':
      'assets/recipe_photos/135-pomaranczowe-serniczki-ze-skyru.jpg',
  'Bananowo-kakaowe muffinki z airfryera':
      'assets/recipe_photos/136-bananowo-kakaowe-muffinki-z-airfryera.jpg',
  'Brzoskwiniowe rożki z ciasta francuskiego':
      'assets/recipe_photos/137-brzoskwiniowe-rozki-z-ciasta-francuskiego.jpg',
  'Sałatka z indykiem, dynią i pęczakiem':
      'assets/recipe_photos/autumn-01-salatka-indyk-dynia-peczak.jpg',
  'Owsianka marchewkowa z orzechami':
      'assets/recipe_photos/autumn-02-owsianka-marchewkowa-orzechy.jpg',
  'Quinoa z wołowiną i dynią':
      'assets/recipe_photos/autumn-03-quinoa-wolowina-dynia.jpg',
  'Meksykańska zupa z dynią i kukurydzą':
      'assets/recipe_photos/autumn-04-zupa-meksykanska-dynia.jpg',
  'Gulasz wołowy z dynią':
      'assets/recipe_photos/autumn-05-gulasz-wegierski-dynia.jpg',
  'Pęczotto z wieprzowiną i burakami':
      'assets/recipe_photos/autumn-06-peczotto-wieprzowina-buraki.jpg',
  'Gnocchi z pieczarkami i szpinakiem':
      'assets/recipe_photos/autumn-07-gnocchi-grzyby-szpinak.jpg',
  'Makaron z karmelizowaną cebulą':
      'assets/recipe_photos/autumn-08-makaron-karmelizowana-cebula.jpg',
  'Chrupiący wrap z jabłkiem i twarogiem':
      'assets/recipe_photos/autumn-09-wrap-szarlotka.jpg',
  'Brukselka z halloumi i pęczakiem':
      'assets/recipe_photos/autumn-10-brukselka-halloumi-peczak.jpg',
  'Nocna owsianka z jabłkiem i orzechami':
      'assets/recipe_photos/autumn-11-nocna-owsianka-jablko-orzechy.jpg',
  'Sałatka z soczewicą, indykiem i dynią':
      'assets/recipe_photos/autumn-12-soczewica-indyk-dynia.jpg',
  'Szakszuka z dynią': 'assets/recipe_photos/autumn-13-szakszuka-dynia.jpg',
  'Jajka po turecku z pieczoną dynią':
      'assets/recipe_photos/autumn-14-jajka-turecku-dynia.jpg',
  'Omlet z kurkami': 'assets/recipe_photos/autumn-15-omlet-kurki.jpg',
  'Kapuśniak z granulatem sojowym':
      'assets/recipe_photos/autumn-16-kapusniak-sojowy.jpg',
  'Sałatka z kurczakiem, dynią i kaszą jaglaną':
      'assets/recipe_photos/autumn-17-salatka-kurczak-dynia-jaglana.jpg',
  'Łosoś z buraczaną kaszą jaglaną':
      'assets/recipe_photos/autumn-18-losos-buraczana-kasza.jpg',
  'Sałatka ze stekiem, burakiem i dynią':
      'assets/recipe_photos/autumn-19-salatka-stek-burak-dynia.jpg',
  'Ciasto dyniowe z mikrofalówki':
      'assets/recipe_photos/autumn-20-ciasto-dyniowe-kubek.jpg',
  'Placki dyniowe z jabłkiem':
      'assets/recipe_photos/autumn-21-placki-dyniowe-jablko.jpg',
  'Curry dyniowe z ananasem':
      'assets/recipe_photos/autumn-22-curry-dyniowe-ananas.jpg',
  'Hummus dyniowy': 'assets/recipe_photos/autumn-23-hummus-dyniowy.jpg',
  'Makaron z dynią i fetą':
      'assets/recipe_photos/autumn-24-makaron-dynia-feta.jpg',
  'Karkówka w sosie grzybowym z puree':
      'assets/recipe_photos/autumn-25-karkowka-grzyby-puree.jpg',
  'Owsianka z suszonymi śliwkami i czekoladą':
      'assets/recipe_photos/autumn-26-owsianka-sliwki-czekolada.jpg',
  'Makaron z camembertem i pomidorami':
      'assets/recipe_photos/autumn-27-makaron-camembert-pomidory.jpg',
  'Bowl z kurczakiem, burakiem i dynią':
      'assets/recipe_photos/autumn-28-bowl-kurczak-burak-dynia.jpg',
  'Pieczona owsianka z gruszkami i imbirem':
      'assets/recipe_photos/autumn-29-pieczona-owsianka-gruszki.jpg',
  'Francuskie trójkąty z jabłkiem':
      'assets/recipe_photos/autumn-30-trojkaty-francuskie-jablko.jpg',
  'Tosty żytnie z ricottą i malinami':
      'assets/recipe_photos/new-01-berry-ricotta-toast.jpg',
  'Rye toast with ricotta and raspberries':
      'assets/recipe_photos/new-01-berry-ricotta-toast.jpg',
  'Muffiny jajeczne ze szpinakiem i cheddarem':
      'assets/recipe_photos/new-02-spinach-cheddar-muffins.jpg',
  'Spinach and Cheddar egg muffins':
      'assets/recipe_photos/new-02-spinach-cheddar-muffins.jpg',
  'Komosa na mleku z borówkami i kokosem':
      'assets/recipe_photos/new-03-blueberry-quinoa-porridge.jpg',
  'Blueberry and coconut breakfast quinoa':
      'assets/recipe_photos/new-03-blueberry-quinoa-porridge.jpg',
  'Grzanki z pastą fasolową i pieczarkami':
      'assets/recipe_photos/new-04-mushroom-beans-toast.jpg',
  'Rye toast with white beans and mushrooms':
      'assets/recipe_photos/new-04-mushroom-beans-toast.jpg',
  'Patelnia z batatem, szpinakiem i jajkami':
      'assets/recipe_photos/new-05-sweet-potato-egg-hash.jpg',
  'Sweet potato and spinach breakfast hash':
      'assets/recipe_photos/new-05-sweet-potato-egg-hash.jpg',
  'Kokosowy pudding chia z mango':
      'assets/recipe_photos/new-06-mango-chia-pudding.jpg',
  'Coconut chia pudding with mango':
      'assets/recipe_photos/new-06-mango-chia-pudding.jpg',
  'Placuszki gryczane z tartym jabłkiem':
      'assets/recipe_photos/new-07-apple-buckwheat-pancakes.jpg',
  'Buckwheat and grated apple pancakes':
      'assets/recipe_photos/new-07-apple-buckwheat-pancakes.jpg',
  'Frittata ziemniaczana z wędzonym łososiem':
      'assets/recipe_photos/new-08-smoked-salmon-potato-frittata.jpg',
  'Smoked salmon and potato frittata':
      'assets/recipe_photos/new-08-smoked-salmon-potato-frittata.jpg',
  'Nocna komosa z malinami i masłem orzechowym':
      'assets/recipe_photos/new-09-peanut-raspberry-overnight-quinoa.jpg',
  'Overnight quinoa with raspberries and peanut butter':
      'assets/recipe_photos/new-09-peanut-raspberry-overnight-quinoa.jpg',
  'Tosty francuskie z żytniego chleba z gruszką':
      'assets/recipe_photos/new-10-pear-rye-french-toast.jpg',
  'Rye French toast with pears':
      'assets/recipe_photos/new-10-pear-rye-french-toast.jpg',
  'Łosoś z pieczonymi ziemniakami i brokułem':
      'assets/recipe_photos/new-11-salmon-broccoli-potato-traybake.jpg',
  'Salmon, potato and broccoli traybake':
      'assets/recipe_photos/new-11-salmon-broccoli-potato-traybake.jpg',
  'Papryki nadziewane indykiem i ryżem':
      'assets/recipe_photos/new-12-turkey-stuffed-peppers.jpg',
  'Turkey and rice stuffed peppers':
      'assets/recipe_photos/new-12-turkey-stuffed-peppers.jpg',
  'Polędwiczka z jabłkami w sosie cydrowym':
      'assets/recipe_photos/new-13-pork-apples-cider.jpg',
  'Pork tenderloin with apples and a cider vinegar glaze':
      'assets/recipe_photos/new-13-pork-apples-cider.jpg',
  'Dorsz w pomidorowej potrawce z białą fasolą':
      'assets/recipe_photos/new-14-cod-white-bean-tomato-stew.jpg',
  'Cod and white bean tomato stew':
      'assets/recipe_photos/new-14-cod-white-bean-tomato-stew.jpg',
  'Komosa z krewetkami, cukinią i limonką':
      'assets/recipe_photos/new-15-prawn-lime-quinoa.jpg',
  'Prawn, courgette and lime quinoa':
      'assets/recipe_photos/new-15-prawn-lime-quinoa.jpg',
  'Pulpeciki z indyka na kremowej polencie':
      'assets/recipe_photos/new-16-turkey-meatball-polenta.jpg',
  'Turkey meatballs with creamy polenta':
      'assets/recipe_photos/new-16-turkey-meatball-polenta.jpg',
  'Pęczak z duszoną wołowiną i pieczarkami':
      'assets/recipe_photos/new-17-beef-mushroom-barley.jpg',
  'Braised beef, mushroom and barley bowl':
      'assets/recipe_photos/new-17-beef-mushroom-barley.jpg',
  'Zapiekanka z bakłażana i czerwonej soczewicy':
      'assets/recipe_photos/new-18-red-lentil-aubergine-bake.jpg',
  'Aubergine and red lentil bake':
      'assets/recipe_photos/new-18-red-lentil-aubergine-bake.jpg',
  'Chili z czarnej fasoli i batatów':
      'assets/recipe_photos/new-19-sweet-potato-black-bean-chilli.jpg',
  'Black bean and sweet potato chilli':
      'assets/recipe_photos/new-19-sweet-potato-black-bean-chilli.jpg',
  'Cytrynowe risotto z groszkiem i ricottą':
      'assets/recipe_photos/new-20-lemon-pea-ricotta-risotto.jpg',
  'Lemon, pea and ricotta risotto':
      'assets/recipe_photos/new-20-lemon-pea-ricotta-risotto.jpg',
  'Zapiekanka z kurczakiem i porem pod ziemniakami':
      'assets/recipe_photos/new-21-chicken-leek-potato-pie.jpg',
  'Chicken and leek pie with a sliced potato topping':
      'assets/recipe_photos/new-21-chicken-leek-potato-pie.jpg',
  'Łosoś duszony w kokosowych pomidorach z fasolką':
      'assets/recipe_photos/new-22-salmon-coconut-tomato-stew.jpg',
  'Coconut and tomato salmon stew with green beans':
      'assets/recipe_photos/new-22-salmon-coconut-tomato-stew.jpg',
  'Pieczone ziemniaki z pieczarkami i cheddarem':
      'assets/recipe_photos/new-23-mushroom-cheddar-jacket.jpg',
  'Jacket potatoes with mushrooms and Cheddar':
      'assets/recipe_photos/new-23-mushroom-cheddar-jacket.jpg',
  'Gołąbki z kapusty pekińskiej z wieprzowiną i imbirem':
      'assets/recipe_photos/new-24-ginger-pork-cabbage-rolls.jpg',
  'Ginger pork and rice cabbage rolls':
      'assets/recipe_photos/new-24-ginger-pork-cabbage-rolls.jpg',
  'Makaron zapiekany z indykiem i brokułem':
      'assets/recipe_photos/new-25-turkey-broccoli-pasta-bake.jpg',
  'Turkey and broccoli pasta bake':
      'assets/recipe_photos/new-25-turkey-broccoli-pasta-bake.jpg',
  'Zupa z czerwonej soczewicy i wędzonej papryki':
      'assets/recipe_photos/new-26-smoky-red-lentil-soup.jpg',
  'Smoky red lentil and tomato soup':
      'assets/recipe_photos/new-26-smoky-red-lentil-soup.jpg',
  'Kremowa zupa z kukurydzą, porem i ziemniakami':
      'assets/recipe_photos/new-27-sweetcorn-leek-chowder.jpg',
  'Sweetcorn, leek and potato chowder':
      'assets/recipe_photos/new-27-sweetcorn-leek-chowder.jpg',
  'Biała fasola w pomidorach ze szpinakiem':
      'assets/recipe_photos/new-28-butter-bean-tomato-skillet.jpg',
  'Tomato, spinach and white bean skillet':
      'assets/recipe_photos/new-28-butter-bean-tomato-skillet.jpg',
  'Frittata z krewetkami i zielonym groszkiem':
      'assets/recipe_photos/new-29-prawn-pea-frittata.jpg',
  'Prawn and pea frittata':
      'assets/recipe_photos/new-29-prawn-pea-frittata.jpg',
  'Wrap z halloumi i pieczoną papryką':
      'assets/recipe_photos/new-30-pepper-halloumi-wrap.jpg',
  'Halloumi and roast pepper wrap':
      'assets/recipe_photos/new-30-pepper-halloumi-wrap.jpg',
  'Sałatka ziemniaczana z wędzonym łososiem i jabłkiem':
      'assets/recipe_photos/new-31-salmon-apple-potato-salad.jpg',
  'Smoked salmon, apple and potato salad':
      'assets/recipe_photos/new-31-salmon-apple-potato-salad.jpg',
  'Sałatka z pieczonych buraków, pomarańczy i orzechów':
      'assets/recipe_photos/new-32-beetroot-orange-walnut-salad.jpg',
  'Roast beetroot, orange and walnut salad':
      'assets/recipe_photos/new-32-beetroot-orange-walnut-salad.jpg',
  'Cytrynowy makaron z białą fasolą i szpinakiem':
      'assets/recipe_photos/new-33-pasta-white-bean-lemon.jpg',
  'Lemon, white bean and spinach pasta':
      'assets/recipe_photos/new-33-pasta-white-bean-lemon.jpg',
  'Smażony ryż z wieprzowiną, groszkiem i jajkiem':
      'assets/recipe_photos/new-34-pork-pea-rice.jpg',
  'Pork, pea and egg fried rice':
      'assets/recipe_photos/new-34-pork-pea-rice.jpg',
  'Grillowana polenta z pomidorkami i fetą':
      'assets/recipe_photos/new-35-polenta-tomato-feta.jpg',
  'Griddled polenta with cherry tomatoes and feta':
      'assets/recipe_photos/new-35-polenta-tomato-feta.jpg',
  'Pieczony kalafior z ciecierzycą i tahini':
      'assets/recipe_photos/new-36-cauliflower-chickpea-traybake.jpg',
  'Roasted cauliflower and chickpeas with tahini':
      'assets/recipe_photos/new-36-cauliflower-chickpea-traybake.jpg',
  'Sałatka z kurczakiem, fasolką i musztardą':
      'assets/recipe_photos/new-37-chicken-green-bean-mustard-salad.jpg',
  'Chicken, green bean and mustard potato salad':
      'assets/recipe_photos/new-37-chicken-green-bean-mustard-salad.jpg',
  'Makaron w sosie z groszku z pieczonym brokułem':
      'assets/recipe_photos/new-38-roasted-broccoli-pea-pasta.jpg',
  'Pasta with pea sauce and roasted broccoli':
      'assets/recipe_photos/new-38-roasted-broccoli-pea-pasta.jpg',
  'Tosty z białą fasolą i roztopionym cheddarem':
      'assets/recipe_photos/new-39-cheddar-bean-toastie.jpg',
  'White bean and Cheddar toastie':
      'assets/recipe_photos/new-39-cheddar-bean-toastie.jpg',
  'Łódeczki z sałaty z indykiem i kapustą':
      'assets/recipe_photos/new-40-turkey-cabbage-lettuce-cups.jpg',
  'Turkey and cabbage lettuce cups':
      'assets/recipe_photos/new-40-turkey-cabbage-lettuce-cups.jpg',
  'Kakaowe kulki z daktyli i kokosa':
      'assets/recipe_photos/new-41-coconut-date-bites.jpg',
  'Cocoa, date and coconut bites':
      'assets/recipe_photos/new-41-coconut-date-bites.jpg',
  'Pieczona ricotta ze śliwkami':
      'assets/recipe_photos/new-42-baked-ricotta-plums.jpg',
  'Baked ricotta with roast plums':
      'assets/recipe_photos/new-42-baked-ricotta-plums.jpg',
  'Jogurt kakaowy z gruszką i orzechami':
      'assets/recipe_photos/new-43-cocoa-pear-yoghurt.jpg',
  'Cocoa yoghurt with pear and walnuts':
      'assets/recipe_photos/new-43-cocoa-pear-yoghurt.jpg',
  'Waniliowy ryż na mleku z pieczonymi brzoskwiniami':
      'assets/recipe_photos/new-44-vanilla-rice-roast-peaches.jpg',
  'Vanilla rice pudding with roast peaches':
      'assets/recipe_photos/new-44-vanilla-rice-roast-peaches.jpg',
  'Ciasto z polenty i malin':
      'assets/recipe_photos/new-45-raspberry-polenta-cake.jpg',
  'Raspberry polenta cake':
      'assets/recipe_photos/new-45-raspberry-polenta-cake.jpg',
  'Czekoladowy krem z ricotty i malin':
      'assets/recipe_photos/new-46-chocolate-ricotta-raspberry.jpg',
  'Chocolate ricotta mousse with raspberries':
      'assets/recipe_photos/new-46-chocolate-ricotta-raspberry.jpg',
  'Owsiane kostki kakaowe z gruszką':
      'assets/recipe_photos/new-47-pear-cocoa-oat-bars.jpg',
  'Pear and cocoa oat squares':
      'assets/recipe_photos/new-47-pear-cocoa-oat-bars.jpg',
  'Pieczone śliwki z chrupiącą żytnią posypką':
      'assets/recipe_photos/new-48-roast-plum-rye-crumb.jpg',
  'Roast plums with rye crumbs':
      'assets/recipe_photos/new-48-roast-plum-rye-crumb.jpg',
  'Zapiekany budyń z komosy z jabłkami i orzechami':
      'assets/recipe_photos/new-49-quinoa-apple-custard.jpg',
  'Baked quinoa and apple custard with walnuts':
      'assets/recipe_photos/new-49-quinoa-apple-custard.jpg',
  'Skyr z rozgniecionymi borówkami i kokosem':
      'assets/recipe_photos/new-50-blueberry-coconut-skyr.jpg',
  'Skyr with crushed blueberries and toasted coconut':
      'assets/recipe_photos/new-50-blueberry-coconut-skyr.jpg',
  'Kasza gryczana na słodko z jabłkami i ricottą':
      'assets/recipe_photos/new-51-sweet-buckwheat-with-apples-and-ricotta.jpg',
  'Sweet buckwheat with apples and ricotta':
      'assets/recipe_photos/new-51-sweet-buckwheat-with-apples-and-ricotta.jpg',
  'Owsianka z pieczoną brzoskwinią i migdałami':
      'assets/recipe_photos/new-52-porridge-with-roast-peaches-and-almonds.jpg',
  'Porridge with roast peaches and almonds':
      'assets/recipe_photos/new-52-porridge-with-roast-peaches-and-almonds.jpg',
  'Grzanki żytnie z pastą buraczaną i jajkiem':
      'assets/recipe_photos/new-53-rye-toast-with-beetroot-spread-and-egg.jpg',
  'Rye toast with beetroot spread and egg':
      'assets/recipe_photos/new-53-rye-toast-with-beetroot-spread-and-egg.jpg',
  'Placuszki z kukurydzy i cheddara':
      'assets/recipe_photos/new-54-sweetcorn-and-cheddar-pancakes.jpg',
  'Sweetcorn and Cheddar pancakes':
      'assets/recipe_photos/new-54-sweetcorn-and-cheddar-pancakes.jpg',
  'Jaglanka kakaowa z malinami':
      'assets/recipe_photos/new-55-cocoa-millet-porridge-with-raspberries.jpg',
  'Cocoa millet porridge with raspberries':
      'assets/recipe_photos/new-55-cocoa-millet-porridge-with-raspberries.jpg',
  'Jajka zapiekane z pieczarkami w kokilkach':
      'assets/recipe_photos/new-56-baked-eggs-with-mushrooms-in-ramekins.jpg',
  'Baked eggs with mushrooms in ramekins':
      'assets/recipe_photos/new-56-baked-eggs-with-mushrooms-in-ramekins.jpg',
  'Skyr z gruszką i granolą z patelni':
      'assets/recipe_photos/new-57-skyr-with-pear-and-stovetop-granola.jpg',
  'Skyr with pear and stovetop granola':
      'assets/recipe_photos/new-57-skyr-with-pear-and-stovetop-granola.jpg',
  'Koktajl bananowy z daktylami i płatkami':
      'assets/recipe_photos/new-58-banana-date-and-oat-shake.jpg',
  'Banana, date and oat shake':
      'assets/recipe_photos/new-58-banana-date-and-oat-shake.jpg',
  'Jajecznica ze szpinakiem i fetą':
      'assets/recipe_photos/new-59-spinach-and-feta-scrambled-eggs.jpg',
  'Spinach and feta scrambled eggs':
      'assets/recipe_photos/new-59-spinach-and-feta-scrambled-eggs.jpg',
  'Cienkie naleśniki z ricottą i mango':
      'assets/recipe_photos/new-60-ricotta-and-mango-crepes.jpg',
  'Ricotta and mango crêpes':
      'assets/recipe_photos/new-60-ricotta-and-mango-crepes.jpg',
  'Paprykarz ze schabu z czerwoną papryką':
      'assets/recipe_photos/new-61-pork-and-red-pepper-paprikash.jpg',
  'Pork and red pepper paprikash':
      'assets/recipe_photos/new-61-pork-and-red-pepper-paprikash.jpg',
  'Dorsz na polencie z pieczoną papryką':
      'assets/recipe_photos/new-62-cod-with-soft-polenta-and-roast-peppers.jpg',
  'Cod with soft polenta and roast peppers':
      'assets/recipe_photos/new-62-cod-with-soft-polenta-and-roast-peppers.jpg',
  'Kurczak pieczony z brzoskwinią i czerwoną cebulą':
      'assets/recipe_photos/new-63-roast-chicken-with-peaches-and-red-onion.jpg',
  'Roast chicken with peaches and red onion':
      'assets/recipe_photos/new-63-roast-chicken-with-peaches-and-red-onion.jpg',
  'Pieczeń z indyka i tartego jabłka':
      'assets/recipe_photos/new-64-turkey-and-apple-meatloaf.jpg',
  'Turkey and apple meatloaf':
      'assets/recipe_photos/new-64-turkey-and-apple-meatloaf.jpg',
  'Zapiekanka ryżowa z mięsem mielonym i bakłażanem':
      'assets/recipe_photos/new-65-pork-and-beef-rice-bake-with-aubergine.jpg',
  'Pork and beef rice bake with aubergine':
      'assets/recipe_photos/new-65-pork-and-beef-rice-bake-with-aubergine.jpg',
  'Kotlety ziemniaczane z łososiem':
      'assets/recipe_photos/new-66-salmon-and-potato-fishcakes.jpg',
  'Salmon and potato fishcakes':
      'assets/recipe_photos/new-66-salmon-and-potato-fishcakes.jpg',
  'Kotlety z czerwonej soczewicy i marchewki':
      'assets/recipe_photos/new-67-red-lentil-and-carrot-patties-with-tahini.jpg',
  'Red lentil and carrot patties with tahini':
      'assets/recipe_photos/new-67-red-lentil-and-carrot-patties-with-tahini.jpg',
  'Lasagne z porem, szpinakiem i ricottą':
      'assets/recipe_photos/new-68-leek-spinach-and-ricotta-lasagne.jpg',
  'Leek, spinach and ricotta lasagne':
      'assets/recipe_photos/new-68-leek-spinach-and-ricotta-lasagne.jpg',
  'Orzo w pomidorach z krewetkami':
      'assets/recipe_photos/new-69-tomato-orzo-with-prawns.jpg',
  'Tomato orzo with prawns':
      'assets/recipe_photos/new-69-tomato-orzo-with-prawns.jpg',
  'Zapiekany kalafior z kurczakiem i cheddarem':
      'assets/recipe_photos/new-70-chicken-and-cauliflower-cheese-bake.jpg',
  'Chicken and cauliflower cheese bake':
      'assets/recipe_photos/new-70-chicken-and-cauliflower-cheese-bake.jpg',
  'Schab pieczony ze śliwkami i pęczakiem':
      'assets/recipe_photos/new-71-roast-pork-loin-with-plums-and-pearl-barley.jpg',
  'Roast pork loin with plums and pearl barley':
      'assets/recipe_photos/new-71-roast-pork-loin-with-plums-and-pearl-barley.jpg',
  'Strogonow z indyka i pieczarek':
      'assets/recipe_photos/new-72-turkey-and-mushroom-stroganoff.jpg',
  'Turkey and mushroom stroganoff':
      'assets/recipe_photos/new-72-turkey-and-mushroom-stroganoff.jpg',
  'Brytyjska zapiekanka z dorszem i groszkiem':
      'assets/recipe_photos/new-73-cod-and-pea-fish-pie.jpg',
  'Cod and pea fish pie':
      'assets/recipe_photos/new-73-cod-and-pea-fish-pie.jpg',
  'Kieszonki francuskie z soczewicą i szpinakiem':
      'assets/recipe_photos/new-74-puff-pastry-pockets-with-lentils-and-spinach.jpg',
  'Puff pastry pockets with lentils and spinach':
      'assets/recipe_photos/new-74-puff-pastry-pockets-with-lentils-and-spinach.jpg',
  'Kokosowy ryż z kukurydzą, limonką i tofu':
      'assets/recipe_photos/new-75-coconut-lime-and-sweetcorn-rice-with-tofu.jpg',
  'Coconut, lime and sweetcorn rice with tofu':
      'assets/recipe_photos/new-75-coconut-lime-and-sweetcorn-rice-with-tofu.jpg',
  'Zupa buraczana z porem i jogurtem':
      'assets/recipe_photos/new-76-beetroot-and-leek-soup-with-yoghurt.jpg',
  'Beetroot and leek soup with yoghurt':
      'assets/recipe_photos/new-76-beetroot-and-leek-soup-with-yoghurt.jpg',
  'Grzanki z groszkiem, miętą i ricottą':
      'assets/recipe_photos/new-77-crushed-pea-mint-and-ricotta-toast.jpg',
  'Crushed pea, mint and ricotta toast':
      'assets/recipe_photos/new-77-crushed-pea-mint-and-ricotta-toast.jpg',
  'Placki z tartych batatów i fety':
      'assets/recipe_photos/new-78-grated-sweet-potato-and-feta-fritters.jpg',
  'Grated sweet potato and feta fritters':
      'assets/recipe_photos/new-78-grated-sweet-potato-and-feta-fritters.jpg',
  'Zupa z pieczonej papryki i pomidorów z żytnim chlebem':
      'assets/recipe_photos/new-79-roast-pepper-and-tomato-bread-soup.jpg',
  'Roast pepper and tomato bread soup':
      'assets/recipe_photos/new-79-roast-pepper-and-tomato-bread-soup.jpg',
  'Papryki nadziewane brokułem, komosą i cheddarem':
      'assets/recipe_photos/new-80-broccoli-quinoa-and-cheddar-stuffed-peppers.jpg',
  'Broccoli, quinoa and Cheddar stuffed peppers':
      'assets/recipe_photos/new-80-broccoli-quinoa-and-cheddar-stuffed-peppers.jpg',
  'Sałatka z pieczonego kalafiora i pęczaku':
      'assets/recipe_photos/new-81-warm-cauliflower-and-pearl-barley-salad.jpg',
  'Warm cauliflower and pearl barley salad':
      'assets/recipe_photos/new-81-warm-cauliflower-and-pearl-barley-salad.jpg',
  'Wrap z wędzonym łososiem i ogórkiem':
      'assets/recipe_photos/new-82-smoked-salmon-and-cucumber-wrap.jpg',
  'Smoked salmon and cucumber wrap':
      'assets/recipe_photos/new-82-smoked-salmon-and-cucumber-wrap.jpg',
  'Surówka z kapusty pekińskiej z jabłkiem i orzechami':
      'assets/recipe_photos/new-83-chinese-cabbage-apple-and-walnut-slaw.jpg',
  'Chinese cabbage, apple and walnut slaw':
      'assets/recipe_photos/new-83-chinese-cabbage-apple-and-walnut-slaw.jpg',
  'Zapiekana polenta z pomidorami i szpinakiem':
      'assets/recipe_photos/new-84-baked-tomato-and-spinach-polenta.jpg',
  'Baked tomato and spinach polenta':
      'assets/recipe_photos/new-84-baked-tomato-and-spinach-polenta.jpg',
  'Grzanki z awokado i krewetkami':
      'assets/recipe_photos/new-85-avocado-and-prawn-rye-toast.jpg',
  'Avocado and prawn rye toast':
      'assets/recipe_photos/new-85-avocado-and-prawn-rye-toast.jpg',
  'Pieczone cebule nadziewane wieprzowiną i pieczarkami':
      'assets/recipe_photos/new-86-baked-onions-stuffed-with-pork-and-mushrooms.jpg',
  'Baked onions stuffed with pork and mushrooms':
      'assets/recipe_photos/new-86-baked-onions-stuffed-with-pork-and-mushrooms.jpg',
  'Pieczone krokiety ziemniaczane z kukurydzą i cheddarem':
      'assets/recipe_photos/new-87-baked-potato-croquettes-with-sweetcorn-and-cheddar.jpg',
  'Baked potato croquettes with sweetcorn and Cheddar':
      'assets/recipe_photos/new-87-baked-potato-croquettes-with-sweetcorn-and-cheddar.jpg',
  'Komosa z fasolką szparagową i sosem tahini':
      'assets/recipe_photos/new-88-quinoa-and-green-bean-salad-with-tahini.jpg',
  'Quinoa and green bean salad with tahini':
      'assets/recipe_photos/new-88-quinoa-and-green-bean-salad-with-tahini.jpg',
  'Sałatka z halloumi i pieczonymi śliwkami':
      'assets/recipe_photos/new-89-warm-halloumi-and-roast-plum-salad.jpg',
  'Warm halloumi and roast plum salad':
      'assets/recipe_photos/new-89-warm-halloumi-and-roast-plum-salad.jpg',
  'Tofu w sezamie z groszkiem i marchewką':
      'assets/recipe_photos/new-90-sesame-tofu-with-crushed-peas-and-carrots.jpg',
  'Sesame tofu with crushed peas and carrots':
      'assets/recipe_photos/new-90-sesame-tofu-with-crushed-peas-and-carrots.jpg',
  'Chrupiące grzanki cynamonowe z dipem jogurtowym':
      'assets/recipe_photos/new-91-cinnamon-rye-crisps-with-yoghurt-dip.jpg',
  'Cinnamon rye crisps with yoghurt dip':
      'assets/recipe_photos/new-91-cinnamon-rye-crisps-with-yoghurt-dip.jpg',
  'Muffiny owsiane z jabłkiem i marchewką':
      'assets/recipe_photos/new-92-apple-and-carrot-oat-muffins.jpg',
  'Apple and carrot oat muffins':
      'assets/recipe_photos/new-92-apple-and-carrot-oat-muffins.jpg',
  'Pucharek jogurtowy z pieczoną śliwką i czekoladą':
      'assets/recipe_photos/new-93-roast-plum-and-dark-chocolate-yoghurt-parfait.jpg',
  'Roast plum and dark chocolate yoghurt parfait':
      'assets/recipe_photos/new-93-roast-plum-and-dark-chocolate-yoghurt-parfait.jpg',
  'Cytrynowe ciasto z ricottą':
      'assets/recipe_photos/new-94-lemon-ricotta-cake.jpg',
  'Lemon ricotta cake': 'assets/recipe_photos/new-94-lemon-ricotta-cake.jpg',
  'Mrożone płatki jogurtowe z mango i migdałami':
      'assets/recipe_photos/new-95-frozen-mango-and-almond-yoghurt-bark.jpg',
  'Frozen mango and almond yoghurt bark':
      'assets/recipe_photos/new-95-frozen-mango-and-almond-yoghurt-bark.jpg',
  'Cytrynowo-makowe ciasteczka owsiane':
      'assets/recipe_photos/new-96-lemon-and-poppy-seed-oat-cookies.jpg',
  'Lemon and poppy seed oat cookies':
      'assets/recipe_photos/new-96-lemon-and-poppy-seed-oat-cookies.jpg',
  'Clafoutis z gruszkami i malinami':
      'assets/recipe_photos/new-97-pear-and-raspberry-clafoutis.jpg',
  'Pear and raspberry clafoutis':
      'assets/recipe_photos/new-97-pear-and-raspberry-clafoutis.jpg',
  'Czekoladowy pudding z polenty z gruszką':
      'assets/recipe_photos/new-98-chocolate-polenta-pudding-with-pear.jpg',
  'Chocolate polenta pudding with pear':
      'assets/recipe_photos/new-98-chocolate-polenta-pudding-with-pear.jpg',
  'Grillowany ananas z miętowym skyrem':
      'assets/recipe_photos/new-99-griddled-pineapple-with-mint-skyr.jpg',
  'Griddled pineapple with mint skyr':
      'assets/recipe_photos/new-99-griddled-pineapple-with-mint-skyr.jpg',
  'Pieczone babeczki ryżowe z kokosem i borówkami':
      'assets/recipe_photos/new-100-baked-blueberry-and-coconut-rice-cups.jpg',
  'Baked blueberry and coconut rice cups':
      'assets/recipe_photos/new-100-baked-blueberry-and-coconut-rice-cups.jpg',
};
