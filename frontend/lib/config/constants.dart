/// Wspólna lista opcji diety — używana zarówno w onboardingu (zapis
/// preferencji profilu), jak i przy generowaniu konkretnego planu
/// (możliwość wyboru innej diety niż domyślna, tylko dla tego planu).
///
/// UWAGA: wartości "name" MUSZĄ dokładnie odpowiadać kluczom w
/// `_DIET_NAME_TO_TAG` w backendzie (app/services/meal_plan_generator.py)
/// — to na ich podstawie backend dopasowuje przepisy do tagów w bazie.
const List<Map<String, String>> kDietOptions = [
  {'name': 'Bez ograniczeń', 'desc': 'Jesz wszystko, na co masz ochotę'},
  {'name': 'Wegetariańska', 'desc': 'Posiłki bez mięsa i ryb'},
  {'name': 'Wegańska', 'desc': 'Posiłki w 100% roślinne'},
  {'name': 'Bezglutenowa', 'desc': 'Dania bez zawartości glutenu'},
  {'name': 'Keto', 'desc': 'Niska zawartość węglowodanów'},
  {'name': 'Wysokobiałkowa', 'desc': 'Dla aktywnych, budujących masę'},
];
