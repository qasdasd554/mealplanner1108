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
  bool _newOnly = false;

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
        // Filtr "Nowość" jest liczony CAŁKOWICIE po stronie klienta (na
        // podstawie createdAt, bez dodatkowego zapytania do backendu) —
        // prostsze niż dodawanie kolejnego parametru API, i wystarczająco
        // szybkie, bo lista przepisów i tak jest już pobrana.
        _recipes = _newOnly ? list.where((r) => r.isNew).toList() : list;
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
              expandedHeight: 60,
              backgroundColor: AppTheme.backgroundColor,
              elevation: 0,
              // UWAGA (przebudowa): dwa przewijane w bok rzędy chipów (9+4
              // pozycji) zamienione na JEDEN przycisk "Filtry" (pokazujący
              // liczbę aktywnych) otwierający panel z WSZYSTKIMI opcjami w
              // układzie zawijanym (Wrap) — elementy przechodzą do nowej
              // linii zamiast wypływać poza ekran, więc PRZEWIJANIE W BOK
              // W OGÓLE nie jest już potrzebne. Ulubione zostaje jako
              // szybki skrót obok (najczęściej przełączany filtr).
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showFilterSheet(context),
                          icon: const Icon(Icons.tune, size: 18),
                          label: Text(
                            _activeFilterCount == 0 ? 'Filtry' : 'Filtry (${_activeFilterCount})',
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _activeFilterCount > 0 ? AppTheme.primaryColor : AppTheme.textPrimary,
                            side: BorderSide(
                              color: _activeFilterCount > 0
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary.withOpacity(0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilterChip(
                        label: const Text('Ulubione', style: TextStyle(fontSize: 13)),
                        avatar: Icon(
                          _favoritesOnly ? Icons.favorite : Icons.favorite_border,
                          size: 15,
                          color: _favoritesOnly ? Colors.white : Colors.redAccent,
                        ),
                        visualDensity: VisualDensity.compact,
                        selected: _favoritesOnly,
                        onSelected: (val) {
                          setState(() => _favoritesOnly = val);
                          _loadRecipes();
                        },
                        selectedColor: Colors.redAccent,
                        labelStyle: TextStyle(color: _favoritesOnly ? Colors.white : null),
                      ),
                    ],
                  ),
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

  /// Liczba obecnie aktywnych filtrów (do etykiety na przycisku "Filtry").
  /// Uwzględnia też Ulubione, mimo że ma osobny, zawsze widoczny chip —
  /// licznik ma pokazywać PRAWDZIWĄ liczbę aktywnych filtrów, niezależnie
  /// od tego, w którym miejscu UI dany filtr się przełącza.
  int get _activeFilterCount {
    var count = 0;
    if (_favoritesOnly) count++;
    if (_communityOnly) count++;
    if (_myRecipesOnly) count++;
    if (_newOnly) count++;
    if (_selectedMealType != null) count++;
    if (_selectedDifficulty != null) count++;
    return count;
  }

  /// Panel ze WSZYSTKIMI filtrami naraz, w układzie zawijanym (Wrap) —
  /// zamiast przewijania w bok, elementy po prostu przechodzą do nowej
  /// linii, gdy zabraknie miejsca w rzędzie. To sedno naprawy: użytkownik
  /// widzi WSZYSTKIE dostępne opcje od razu, bez przesuwania palcem.
  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void applyAndClose() {
              Navigator.of(sheetContext).pop();
              _loadRecipes();
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Filtry', style: Theme.of(sheetContext).textTheme.titleLarge),
                          if (_activeFilterCount > 0)
                            TextButton(
                              onPressed: () {
                                setSheetState(() {
                                  _communityOnly = false;
                                  _myRecipesOnly = false;
                                  _newOnly = false;
                                  _selectedMealType = null;
                                  _selectedDifficulty = null;
                                });
                              },
                              child: const Text('Wyczyść'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Specjalne',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Nowość'),
                            avatar: const Icon(Icons.fiber_new_outlined, size: 16),
                            selected: _newOnly,
                            onSelected: (val) => setSheetState(() => _newOnly = val),
                            selectedColor: AppTheme.secondaryColor.withOpacity(0.25),
                          ),
                          FilterChip(
                            label: const Text('Społeczność'),
                            avatar: const Icon(Icons.groups_outlined, size: 16),
                            selected: _communityOnly,
                            onSelected: (val) => setSheetState(() => _communityOnly = val),
                            selectedColor: AppTheme.secondaryColor.withOpacity(0.25),
                          ),
                          FilterChip(
                            label: const Text('Moje'),
                            avatar: const Icon(Icons.person_outline, size: 16),
                            selected: _myRecipesOnly,
                            onSelected: (val) => setSheetState(() => _myRecipesOnly = val),
                            selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Typ posiłku',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Wszystkie'),
                            selected: _selectedMealType == null,
                            onSelected: (_) => setSheetState(() => _selectedMealType = null),
                          ),
                          ChoiceChip(
                            label: const Text('Śniadania'),
                            selected: _selectedMealType == 'śniadanie',
                            onSelected: (_) => setSheetState(() => _selectedMealType = 'śniadanie'),
                          ),
                          ChoiceChip(
                            label: const Text('Obiady'),
                            selected: _selectedMealType == 'obiad',
                            onSelected: (_) => setSheetState(() => _selectedMealType = 'obiad'),
                          ),
                          ChoiceChip(
                            label: const Text('Kolacje'),
                            selected: _selectedMealType == 'kolacja',
                            onSelected: (_) => setSheetState(() => _selectedMealType = 'kolacja'),
                          ),
                          ChoiceChip(
                            label: const Text('Przekąski'),
                            selected: _selectedMealType == 'przekąska',
                            onSelected: (_) => setSheetState(() => _selectedMealType = 'przekąska'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Trudność',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Każda'),
                            selected: _selectedDifficulty == null,
                            onSelected: (_) => setSheetState(() => _selectedDifficulty = null),
                          ),
                          ChoiceChip(
                            label: const Text('Łatwe'),
                            selected: _selectedDifficulty == 'łatwy',
                            onSelected: (_) => setSheetState(() => _selectedDifficulty = 'łatwy'),
                          ),
                          ChoiceChip(
                            label: const Text('Średnie'),
                            selected: _selectedDifficulty == 'średni',
                            onSelected: (_) => setSheetState(() => _selectedDifficulty = 'średni'),
                          ),
                          ChoiceChip(
                            label: const Text('Trudne'),
                            selected: _selectedDifficulty == 'trudny',
                            onSelected: (_) => setSheetState(() => _selectedDifficulty = 'trudny'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: applyAndClose,
                          child: const Text('Pokaż wyniki'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
