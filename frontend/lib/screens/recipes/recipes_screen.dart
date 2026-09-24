import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/recipe.dart';
import '../../models/recipe_import_job.dart';
import '../../config/constants.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/decorative_circles.dart';
import '../../widgets/recipe_favorite_button.dart';
import '../../widgets/premium_feature_tag.dart';
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
  RecipeImportJob? _activeImport;
  Timer? _importPollTimer;
  Timer? _searchTimer;
  final TextEditingController _searchController = TextEditingController();
  bool _checkingImport = false;
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _nextSkip = 0;
  int _requestVersion = 0;
  static const int _pageSize = 30;
  String _searchQuery = '';
  // Sortowanie listy: 'name' | 'kcal_asc' | 'kcal_desc' | 'prep_time'.
  // 'kcal_*' sortuje po kaloriach NA JEDNĄ PORCJĘ (czyli na osobę),
  // nie po sumie dla całego przepisu — patrz _kcal_per_serving_expr
  // w backend/app/api/v1/recipes.py.
  String _sortBy = 'name';
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
    _loadImportStatus();
  }

  @override
  void dispose() {
    _importPollTimer?.cancel();
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setSearchQuery(String value) {
    _searchTimer?.cancel();
    ++_requestVersion;
    setState(() => _searchQuery = value);
    _searchTimer = Timer(const Duration(milliseconds: 350), _loadRecipes);
  }

  Future<void> _loadImportStatus() async {
    if (_checkingImport) return;
    _checkingImport = true;
    try {
      final jobs = await _recipeService.getRecentRecipeImportJobs();
      if (!mounted) return;
      RecipeImportJob? active;
      for (final job in jobs) {
        if (job.isActive) {
          active = job;
          break;
        }
      }
      final wasActive = _activeImport != null;
      setState(() => _activeImport = active);
      _importPollTimer?.cancel();
      if (active != null) {
        _importPollTimer = Timer.periodic(
          const Duration(seconds: 10), (_) => _loadImportStatus(),
        );
      } else if (wasActive) {
        _loadRecipes();
      }
    } catch (_) {
      // Błąd statusu nie może blokować przeglądania przepisów.
    } finally {
      _checkingImport = false;
    }
  }

  Future<void> _loadRecipes() async {
    final requestVersion = ++_requestVersion;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = false;
      _nextSkip = 0;
    });

    try {
      // "Moje" to osobny endpoint (GET /recipes/mine) — istniał już w
      // backendzie i w serwisie, tylko nigdy nie był podłączony pod
      // żaden przełącznik w interfejsie.
      final list = _myRecipesOnly
          ? await _recipeService.getMyRecipes(
              sortBy: _sortBy == 'name' ? 'newest' : _sortBy,
              favoritesOnly: _favoritesOnly,
              newOnly: _newOnly,
              communityOnly: _communityOnly,
              search: _searchQuery,
              mealType: _selectedMealType,
              difficulty: _selectedDifficulty,
              tag: _selectedDietTag != null ? kDietNameToTag[_selectedDietTag] : null,
              limit: _pageSize,
            )
          : await _recipeService.getRecipes(
              search: _searchQuery,
              mealType: _selectedMealType,
              difficulty: _selectedDifficulty,
              tag: _selectedDietTag != null ? kDietNameToTag[_selectedDietTag] : null,
              favoritesOnly: _favoritesOnly,
              newOnly: _newOnly,
              communityOnly: _communityOnly,
              sortBy: _sortBy,
              limit: _pageSize,
            );
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _recipes = list;
        _nextSkip = list.length;
        _hasMore = list.length == _pageSize;
      });
    } catch (e) {
      if (!mounted || requestVersion != _requestVersion) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            duration: const Duration(seconds: 3),
          content: Text('Błąd podczas pobierania przepisów: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final requestVersion = _requestVersion;
    final skip = _nextSkip;
    setState(() => _isLoadingMore = true);
    try {
      final list = _myRecipesOnly
          ? await _recipeService.getMyRecipes(
              sortBy: _sortBy == 'name' ? 'newest' : _sortBy,
              favoritesOnly: _favoritesOnly,
              newOnly: _newOnly,
              communityOnly: _communityOnly,
              search: _searchQuery,
              mealType: _selectedMealType,
              difficulty: _selectedDifficulty,
              tag: _selectedDietTag != null ? kDietNameToTag[_selectedDietTag] : null,
              limit: _pageSize,
              skip: skip,
            )
          : await _recipeService.getRecipes(
              search: _searchQuery,
              mealType: _selectedMealType,
              difficulty: _selectedDifficulty,
              tag: _selectedDietTag != null ? kDietNameToTag[_selectedDietTag] : null,
              favoritesOnly: _favoritesOnly,
              newOnly: _newOnly,
              communityOnly: _communityOnly,
              sortBy: _sortBy,
              limit: _pageSize,
              skip: skip,
            );
      if (!mounted || requestVersion != _requestVersion) return;
      final seen = _recipes.map((r) => r.id).toSet();
      setState(() {
        _recipes.addAll(list.where((r) => seen.add(r.id)));
        _nextSkip += list.length;
        _hasMore = list.length == _pageSize;
      });
    } catch (e) {
      if (mounted && requestVersion == _requestVersion) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Nie udało się wczytać kolejnych przepisów: $e'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    } finally {
      if (mounted && requestVersion == _requestVersion) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Przepisy'),
        actions: [
          if (_activeImport != null)
            IconButton(
              tooltip: 'Trwa dodawanie przepisu przez AI',
              icon: const SizedBox(
                width: 24,
                height: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 15),
                    CircularProgressIndicator(strokeWidth: 2),
                  ],
                ),
              ),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AiAddRecipeScreen(),
                ));
                _loadImportStatus();
              },
            ),
          // UWAGA (naprawa widoczności): zwykła, konturowa ikona ledwo
          // było widać na pasku — teraz wypełniona, w złotym kolorze
          // trofeum, na delikatnym tle, z subtelną animacją pulsowania,
          // żeby wyraźnie zachęcała do sprawdzenia cotygodniowego
          // konkursu, nie ginęła obok innych, zwykłych ikon.
          Container(
            // Odstęp zwiększony z 4 na 14 px — jedyna ikona w tym pasku
            // siedziała praktycznie przyklejona do prawej krawędzi
            // ekranu, bez żadnego oddechu.
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE0A62E).withOpacity(0.15),
            ),
            child: IconButton(
              icon: const Icon(Icons.emoji_events, color: Color(0xFFE0A62E)),
              tooltip: 'Ranking autorów przepisów',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecipeLeaderboardScreen()),
                );
              },
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(duration: 1200.ms, begin: const Offset(1, 1), end: const Offset(1.08, 1.08)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Szukaj przepisu...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Wyczyść wyszukiwanie',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _setSearchQuery('');
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                fillColor: AppTheme.surfaceColor.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const DecorativeCircles(),
          NestedScrollView(
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
              expandedHeight: 80,
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
                : CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildRecipeCard(_recipes[index]),
                            childCount: _recipes.length,
                          ),
                        ),
                      ),
                      if (_hasMore)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 96),
                            child: OutlinedButton.icon(
                              onPressed: _isLoadingMore ? null : _loadMore,
                              icon: _isLoadingMore
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.expand_more),
                              label: Text(_isLoadingMore ? 'Wczytywanie…' : 'Pokaż więcej przepisów'),
                            ),
                          ),
                        )
                      else
                        const SliverToBoxAdapter(child: SizedBox(height: 96)),
                    ],
                  ),
      ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text('Dodaj przepis', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 16),
                Text('Z pomocą AI', style: Theme.of(sheetContext).textTheme.titleMedium),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Zrób zdjęcie'),
                  subtitle: const Text('Przepisu albo gotowego dania'),
                  trailing: const PremiumFeatureTag(
                    label: 'PREMIUM / 2 PKT',
                    fontSize: 8,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AiAddRecipeScreen(initialTabIndex: 1),
                    )).then((_) { if (mounted) _loadImportStatus(); });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.text_snippet_outlined),
                  title: const Text('Wklej tekst'),
                  trailing: const PremiumFeatureTag(
                    label: 'PREMIUM / 2 PKT',
                    fontSize: 8,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AiAddRecipeScreen(initialTabIndex: 0),
                    )).then((_) { if (mounted) _loadImportStatus(); });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Wklej link'),
                  trailing: const PremiumFeatureTag(
                    label: 'PREMIUM / 2 PKT',
                    fontSize: 8,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AiAddRecipeScreen(initialTabIndex: 2),
                    )).then((_) { if (mounted) _loadImportStatus(); });
                  },
                ),
                const SizedBox(height: 8),
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
    // Sortowanie jest teraz częścią panelu, więc licznik musi je
    // uwzględniać — inaczej użytkownik nie widziałby, że lista jest
    // ułożona inaczej niż domyślnie (alfabetycznie).
    if (_sortBy != 'name') count++;
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
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text('Filtry', style: Theme.of(sheetContext).textTheme.titleLarge),
                          if (_moreFiltersActiveCount > 0)
                            TextButton(
                              onPressed: () {
                                setSheetState(() {
                                  _selectedMealType = null;
                                  _selectedDifficulty = null;
                                  _selectedDietTag = null;
                                  _sortBy = 'name';
                                });
                              },
                              child: const Text('Wyczyść'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sortowanie',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in const {
                            'name': 'Alfabetycznie',
                            'kcal_asc': 'Kalorie: mniej',
                            'kcal_desc': 'Kalorie: więcej',
                            'prep_time': 'Czas: najszybsze',
                          }.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              selected: _sortBy == entry.key,
                              onSelected: (_) => setSheetState(() => _sortBy = entry.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                          ChoiceChip(
                            label: const Text('Desery'),
                            selected: _selectedMealType == 'deser',
                            onSelected: (_) => setSheetState(() => _selectedMealType = 'deser'),
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
              flex: 4,
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
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
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
                        Flexible(
                          child: Row(
                            // Kcal na porcję (nie na cały przepis) — to jest
                            // wartość, jakiej ktoś przeglądający listę przepisów
                            // się spodziewa (jak na etykiecie dania, nie garnka).
                            // Zabezpieczenie przed dzieleniem przez zero: gdyby
                            // servings kiedyś było 0 (błędne dane), Dart rzuca
                            // wyjątkiem przy .round() na Infinity i wywala ekran.
                            children: [
                              Icon(Icons.schedule, size: 13, color: AppTheme.textSecondary),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  '${recipe.totalTimeMin} min • ${(recipe.nutritionTotal.kcal / (recipe.servings > 0 ? recipe.servings : 1)).round()} kcal/porcję',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
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
