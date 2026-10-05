/// Mapowanie 137 oficjalnych przepisów -> lokalne zdjęcie dania.
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
};
