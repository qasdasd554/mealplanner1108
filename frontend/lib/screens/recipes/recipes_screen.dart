import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/recipe_favorite_button.dart';
import 'recipe_leaderboard_screen.dart';
import 'manual_add_recipe_screen.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final RecipeService _recipeService = RecipeService();
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedMealType;
  String? _selectedDifficulty;
  bool _favoritesOnly = false;
  bool _communityOnly = false;
  bool _myRecipesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // "Moje" to osobny endpoint (GET /recipes/mine) — istniał już w
      // backendzie i w serwisie, tylko nigdy nie był podłączony pod
      // żaden przełącznik w interfejsie.
      final list = _myRecipesOnly
          ? await _recipeService.getMyRecipes()
          : await _recipeService.getRecipes(
              search: _searchQuery,
              mealType: _selectedMealType,
              difficulty: _selectedDifficulty,
              favoritesOnly: _favoritesOnly,
              communityOnly: _communityOnly,
            );
      if (!mounted) return;
      setState(() {
        _recipes = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Błąd podczas pobierania przepisów: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Przepisy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Ranking autorów przepisów',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecipeLeaderboardScreen()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _loadRecipes();
              },
              decoration: InputDecoration(
                hintText: 'Szukaj przepisu...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                fillColor: AppTheme.surfaceColor.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
      body: NestedScrollView(
        // UWAGA (naprawa): pasek filtrów przebudowany na SliverAppBar
        // (floating+snap) zamiast zwykłego Column — to standardowy
        // wzorzec Fluttera "chowaj przy przewijaniu w dół, pokaż od razu
        // przy najmniejszym przewinięciu w górę". Daje więcej miejsca na
        // siatkę przepisów, gdy użytkownik przegląda listę.
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 0,
              floating: true,
              snap: true,
              expandedHeight: 118,
              backgroundColor: AppTheme.backgroundColor,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Column(
                  children: [
                    // 1. Filtry po typie posiłku
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          _buildFilterChip('Wszystkie', null, _selectedMealType == null, (val) {
                            setState(() {
                              _selectedMealType = null;
                            });
                            _loadRecipes();
                          }),
                          const SizedBox(width: 8),
                          Container(width: 1, height: 20, color: AppTheme.textSecondary.withOpacity(0.2)),
                          const SizedBox(width: 8),
                          // Ulubione — zaraz po "Wszystkie", bo to najważniejszy
                          // skrót (nie jest to filtr typu posiłku, tylko przełącznik
                          // "pokaż tylko to, co lubię").
                          FilterChip(
                            label: const Text('Ulubione', style: TextStyle(fontSize: 13)),
                            avatar: Icon(
                              _favoritesOnly ? Icons.favorite : Icons.favorite_border,
                              size: 15,
                              color: _favoritesOnly ? Colors.white : Colors.redAccent,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            selected: _favoritesOnly,
                            onSelected: (val) {
                              setState(() => _favoritesOnly = val);
                              _loadRecipes();
                            },
                            selectedColor: Colors.redAccent,
                            labelStyle: TextStyle(color: _favoritesOnly ? Colors.white : null),
                          ),
                          const SizedBox(width: 6),
                          // Filtr "Społeczność" — pokazuje TYLKO przepisy dodane przez
                          // innych użytkowników i zaakceptowane do wspólnego katalogu
                          // (nie 81 oficjalnych, nie własne prywatne).
                          FilterChip(
                            label: const Text('Społeczność', style: TextStyle(fontSize: 13)),
                            avatar: Icon(
                              Icons.groups_outlined,
                              size: 15,
                              color: _communityOnly ? Colors.white : AppTheme.secondaryColor,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            selected: _communityOnly,
                            onSelected: (val) {
                              setState(() => _communityOnly = val);
                              _loadRecipes();
                            },
                            selectedColor: AppTheme.secondaryColor,
                            labelStyle: TextStyle(color: _communityOnly ? Colors.white : null),
                          ),
                          const SizedBox(width: 6),
                          // Filtr "Moje" — WYŁĄCZNIE przepisy dodane przez
                          // zalogowanego użytkownika (dowolną metodą: ręcznie, AI,
                          // z linku/zdjęcia) — niezależnie od tego, czy są jeszcze
                          // prywatne, czekają na akceptację, czy już są publiczne.
                          FilterChip(
                            label: const Text('Moje', style: TextStyle(fontSize: 13)),
                            avatar: Icon(
                              Icons.person_outline,
                              size: 15,
                              color: _myRecipesOnly ? Colors.white : AppTheme.primaryColor,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            selected: _myRecipesOnly,
                            onSelected: (val) {
                              setState(() => _myRecipesOnly = val);
                              _loadRecipes();
                            },
                            selectedColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(color: _myRecipesOnly ? Colors.white : null),
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip('Śniadania', 'śniadanie', _selectedMealType == 'śniadanie', (val) {
                            setState(() {
                              _selectedMealType = 'śniadanie';
                            });
                            _loadRecipes();
                          }),
                          const SizedBox(width: 6),
                          _buildFilterChip('Obiady', 'obiad', _selectedMealType == 'obiad', (val) {
                            setState(() {
                              _selectedMealType = 'obiad';
                            });
                            _loadRecipes();
                          }),
                          const SizedBox(width: 6),
                          _buildFilterChip('Kolacje', 'kolacja', _selectedMealType == 'kolacja', (val) {
                            setState(() {
                              _selectedMealType = 'kolacja';
                            });
                            _loadRecipes();
                          }),
                          const SizedBox(width: 6),
                          _buildFilterChip('Przekąski', 'przekąska', _selectedMealType == 'przekąska', (val) {
                            setState(() {
                              _selectedMealType = 'przekąska';
                            });
                            _loadRecipes();
                          }),
                        ],
                      ),
                    ),

                    // 2. Filtry trudności
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      child: Row(
                        children: [
                          _buildFilterChip('Każda trudność', null, _selectedDifficulty == null, (val) {
                            setState(() {
                              _selectedDifficulty = null;
                            });
                            _loadRecipes();
                          }),
                          const SizedBox(width: 6),
                          _buildFilterChip('Łatwe', 'łatwy', _selectedDifficulty == 'łatwy', (val) {
                            setState(() {
                              _selectedDifficulty = 'łatwy';
                            });
                            _loadRecipes();
                          }),
                          const SizedBox(width: 6),
                          _buildFilterChip('Średnie', 'średni', _selectedDifficulty == 'średni', (val) {
                            setState(() {
                              _selectedDifficulty = 'średni';
                            });
                            _loadRecipes();
                          }),
                          const SizedBox(width: 6),
                          _buildFilterChip('Trudne', 'trudny', _selectedDifficulty == 'trudny', (val) {
                            setState(() {
                              _selectedDifficulty = 'trudny';
                            });
                            _loadRecipes();
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _recipes.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: _recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = _recipes[index];
                      return _buildRecipeCard(recipe);
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Prowadzi najpierw do zwykłego, ręcznego formularza (jak w
        // Śledzeniu kalorii) — dodawanie przez AI jest dostępne jako
        // opcja Z POZIOMU tego ekranu, nie jako pierwszy krok.
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ManualAddRecipeScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Dodaj przepis'),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String? value,
    bool isSelected,
    ValueChanged<bool> onSelected,
  ) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      // UWAGA (naprawa): gęstość i wypełnienie zmniejszone, żeby więcej
      // filtrów mieściło się na ekranie bez konieczności przewijania —
      // to była jedna z głównych skarg (filtry "słabo widoczne, bo
      // trzeba je przewijać").
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
        width: 1,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return GestureDetector(
      // UWAGA (naprawa): bez klucza powiązanego z ID przepisu, GridView
      // przy zmianie listy (np. przełączenie filtra "Ulubione") mogło
      // odzyskać ten sam obiekt stanu (w tym serca ulubionych) dla
      // zupełnie innego przepisu na tej samej pozycji siatki, pokazując
      // nieaktualny/błędny stan przez chwilę po przeładowaniu.
      key: ValueKey(recipe.id),
      onTap: () async {
        // UWAGA (uzupełnienie): po dodaniu możliwości usuwania własnego
        // przepisu na ekranie szczegółów, lista tutaj musi się odświeżyć
        // po powrocie — inaczej usunięty przepis zostawałby widoczny
        // jako "widmowy" wpis, dopóki coś innego nie wymusiłoby
        // ponownego pobrania.
        await Navigator.of(context).pushNamed(
          '/recipe/detail',
          arguments: recipe,
        );
        if (mounted) _loadRecipes();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Górna część z gradientem / placeholderem (Premium look)
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    // UWAGA (naprawa — prawdziwy błąd): wcześniej ten warunek
                    // sprawdzał TYLKO realPhotoAsset (zdjęcia wbudowane w
                    // aplikację dla oryginalnych 94 przepisów) i przy braku
                    // od razu pokazywał ilustrację kategorii — CAŁKOWICIE
                    // pomijając RecipePhoto (a więc i jego poprawną logikę
                    // fallbacku do photoBase64). Efekt: przepisy z prawdziwym
                    // zdjęciem w bazie (photoBase64), ale bez wbudowanego
                    // assetu, pokazywały tylko generyczną ilustrację —
                    // dokładnie przypadek nowo dodanych przepisów. RecipePhoto
                    // samo poprawnie wybiera: realPhotoAsset -> photoBase64 ->
                    // categoryImageAsset, więc wystarczy wywoływać je zawsze.
                    child: RecipePhoto(recipe: recipe, showAiBadge: false),
                  ),
                  // Serce w rogu miniaturki — szybkie dodanie/usunięcie
                  // z ulubionych bez wchodzenia w szczegóły przepisu.
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: RecipeFavoriteButton(
                        recipe: recipe,
                        activeColor: Colors.redAccent,
                        inactiveColor: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  // Znaczek "Nowość" — widoczny przez 14 dni od dodania
                  // przepisu, niezależnie czy dodany "z zewnątrz" (przy
                  // aktualizacji katalogu) czy przez użytkownika.
                  if (recipe.isNew)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Nowość',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Dolne informacje
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.mealType.toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryColor.withOpacity(0.8),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 14,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          // Kcal na porcję (nie na cały przepis) — to jest
                          // wartość, jakiej ktoś przeglądający listę przepisów
                          // się spodziewa (jak na etykiecie dania, nie garnka).
                          // Zabezpieczenie przed dzieleniem przez zero: gdyby
                          // servings kiedyś było 0 (błędne dane), Dart rzuca
                          // wyjątkiem przy .round() na Infinity i wywala ekran.
                          '⏱ ${recipe.totalTimeMin} min • ${(recipe.nutritionTotal.kcal / (recipe.servings > 0 ? recipe.servings : 1)).round()} kcal/porcję',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                        Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: const BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Text(
                            recipe.difficulty,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9), duration: 200.ms);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Brak przepisów',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Spróbuj zmienić parametry wyszukiwania.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
