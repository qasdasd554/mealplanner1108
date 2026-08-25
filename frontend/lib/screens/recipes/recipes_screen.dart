import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/recipe.dart';
import '../../config/constants.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/recipe_favorite_button.dart';
import 'recipe_leaderboard_screen.dart';
import 'manual_add_recipe_screen.dart';
import 'ai_add_recipe_screen.dart';

class RecipesScreen extends StatefulWidget {
  // Pozwala przejść od razu do filtra "Moje" — używane np. przez skrót w
  // zakładce Premium ("Publikuj przepisy"), żeby nie zmuszać użytkownika
  // do ręcznego przełączania filtra po dotarciu na ten ekran.
  final bool initialMyRecipesOnly;

  const RecipesScreen({super.key, this.initialMyRecipesOnly = false});

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
  late bool _myRecipesOnly = widget.initialMyRecipesOnly;
  bool _newOnly = false;
  String? _selectedDietTag;

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
              tag: _selectedDietTag != null ? kDietNameToTag[_selectedDietTag] : null,
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
              expandedHeight: 70,
              backgroundColor: AppTheme.backgroundColor,
              elevation: 0,
              // UWAGA (przebudowa #2): teraz WSZYSTKIE 4 szybkie filtry
              // (Ulubione/Moje/Nowość/Społeczność) widoczne naraz w jednym
              // rzędzie — gwarancja mieszczenia się na KAŻDYM ekranie
              // wynika z użycia Expanded (5 równych segmentów: 4 filtry +
              // "Więcej filtrów"), więc fizycznie nie da się przewinąć w
              // bok — nie ma czego przewijać, cała szerokość jest już
              // wykorzystana. Reszta (typ posiłku, trudność, dieta)
              // przeniesiona do panelu "Więcej filtrów".
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _buildQuickToggle(
                        icon: Icons.favorite_border,
                        activeIcon: Icons.favorite,
                        label: 'Ulubione',
                        isActive: _favoritesOnly,
                        activeColor: Colors.redAccent,
                        onTap: () {
                          setState(() => _favoritesOnly = !_favoritesOnly);
                          _loadRecipes();
                        },
                      ),
                      _buildQuickToggle(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Moje',
                        isActive: _myRecipesOnly,
                        activeColor: AppTheme.primaryColor,
                        onTap: () {
                          setState(() => _myRecipesOnly = !_myRecipesOnly);
                          _loadRecipes();
                        },
                      ),
                      _buildQuickToggle(
                        icon: Icons.fiber_new_outlined,
                        activeIcon: Icons.fiber_new,
                        label: 'Nowość',
                        isActive: _newOnly,
                        activeColor: AppTheme.accentColor,
                        onTap: () {
                          setState(() => _newOnly = !_newOnly);
                          _loadRecipes();
                        },
                      ),
                      _buildQuickToggle(
                        icon: Icons.groups_outlined,
                        activeIcon: Icons.groups,
                        label: 'Społeczność',
                        isActive: _communityOnly,
                        activeColor: AppTheme.secondaryColor,
                        onTap: () {
                          setState(() => _communityOnly = !_communityOnly);
                          _loadRecipes();
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showFilterSheet(context),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _moreFiltersActiveCount > 0
                                  ? AppTheme.primaryColor.withOpacity(0.12)
                                  : AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _moreFiltersActiveCount > 0
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      Icons.tune,
                                      size: 18,
                                      color: _moreFiltersActiveCount > 0
                                          ? AppTheme.primaryColor
                                          : AppTheme.textSecondary,
                                    ),
                                    if (_moreFiltersActiveCount > 0)
                                      Positioned(
                                        right: -6,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(minWidth: 13, minHeight: 13),
                                          child: Text(
                                            '$_moreFiltersActiveCount',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 8, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Więcej',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: _moreFiltersActiveCount > 0
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
        // UWAGA (naprawa widoczności): wcześniej FAB prowadził od razu do
        // ręcznego formularza, a dodawanie przez AI było schowane jako
        // mały TextButton w pasku AppBar tamtego ekranu — łatwo było go
        // przeoczyć. Teraz FAB otwiera wybór z DUŻĄ, wyróżnioną kartą AI
        // na pierwszym miejscu (główna, zalecana ścieżka) i mniejszą
        // opcją ręczną poniżej.
        onPressed: () => _showAddRecipeChoice(context),
        icon: const Icon(Icons.add),
        label: const Text('Dodaj przepis'),
      ),
    );
  }

  void _showAddRecipeChoice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dodaj przepis', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 16),
                // Duża, wyróżniona karta AI — GŁÓWNA, zalecana ścieżka.
                GestureDetector(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiAddRecipeScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dodaj przez AI',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Zdjęcie, tekst albo link — AI zrobi resztę',
                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Mniejsza, drugorzędna opcja ręczna.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ManualAddRecipeScreen()),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Dodaj ręcznie'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Liczba obecnie aktywnych filtrów (do etykiety na przycisku "Filtry").
  /// Uwzględnia też Ulubione, mimo że ma osobny, zawsze widoczny chip —
  /// licznik ma pokazywać PRAWDZIWĄ liczbę aktywnych filtrów, niezależnie
  /// od tego, w którym miejscu UI dany filtr się przełącza.
  /// Liczba aktywnych filtrów w panelu "Więcej filtrów" — CELOWO nie
  /// uwzględnia Ulubione/Moje/Nowość/Społeczność, bo te są teraz zawsze
  /// widoczne bezpośrednio w rzędzie (ich stan widać na pierwszy rzut
  /// oka, więc dublowanie ich w liczniku panelu byłoby mylące).
  int get _moreFiltersActiveCount {
    var count = 0;
    if (_selectedMealType != null) count++;
    if (_selectedDifficulty != null) count++;
    if (_selectedDietTag != null) count++;
    return count;
  }

  /// Kompaktowy, zawsze widoczny przełącznik filtra — szerokość
  /// wymuszona przez Expanded w rodzicu (Row z 5 równymi segmentami),
  /// więc GWARANTOWANE jest zmieszczenie się na każdym ekranie bez
  /// przewijania w bok.
  Widget _buildQuickToggle({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.12) : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? activeColor : AppTheme.textSecondary.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? activeIcon : icon, size: 18, color: isActive ? activeColor : AppTheme.textSecondary),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: isActive ? activeColor : AppTheme.textSecondary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                          if (_moreFiltersActiveCount > 0)
                            TextButton(
                              onPressed: () {
                                setSheetState(() {
                                  _selectedMealType = null;
                                  _selectedDifficulty = null;
                                  _selectedDietTag = null;
                                });
                              },
                              child: const Text('Wyczyść'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Dieta',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Wszystkie'),
                            selected: _selectedDietTag == null,
                            onSelected: (_) => setSheetState(() => _selectedDietTag = null),
                          ),
                          // Pomijamy "Bez ograniczeń" z kDietOptions — tutaj
                          // odpowiednikiem "braku filtra" jest opcja
                          // "Wszystkie" powyżej, więc zaczynamy od indeksu 1.
                          for (final diet in kDietOptions.skip(1))
                            ChoiceChip(
                              label: Text(diet['name']!),
                              selected: _selectedDietTag == diet['name'],
                              onSelected: (_) => setSheetState(() => _selectedDietTag = diet['name']),
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
