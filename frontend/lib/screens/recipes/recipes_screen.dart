import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../models/recipe_import_job.dart';
import '../../config/constants.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/planner_components.dart';
import '../../widgets/premium_feature_tag.dart';
import 'recipe_leaderboard_screen.dart';
import 'manual_add_recipe_screen.dart';
import 'ai_add_recipe_screen.dart';

enum _AddRecipeChoice { photo, text, link, manual }

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
  bool _isBackgroundRefreshing = false;
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
          const Duration(seconds: 10),
          (_) => _loadImportStatus(),
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

  Future<void> _loadRecipes({bool preserveCurrent = false}) async {
    final requestVersion = ++_requestVersion;
    setState(() {
      _isLoading = true;
      _isBackgroundRefreshing = preserveCurrent && _recipes.isNotEmpty;
      _isLoadingMore = false;
      _hasMore = false;
      _nextSkip = 0;
    });

    try {
      // "Moje" to osobny endpoint (GET /recipes/mine) — istniał już w
      // backendzie i w serwisie, tylko nigdy nie był podłączony pod
      // żaden przełącznik w interfejsie.
      final list =
          _myRecipesOnly
              ? await _recipeService.getMyRecipes(
                sortBy: _sortBy == 'name' ? 'newest' : _sortBy,
                favoritesOnly: _favoritesOnly,
                newOnly: _newOnly,
                communityOnly: _communityOnly,
                search: _searchQuery,
                mealType: _selectedMealType,
                difficulty: _selectedDifficulty,
                tag:
                    _selectedDietTag != null
                        ? kDietNameToTag[_selectedDietTag]
                        : null,
                limit: _pageSize,
              )
              : await _recipeService.getRecipes(
                search: _searchQuery,
                mealType: _selectedMealType,
                difficulty: _selectedDifficulty,
                tag:
                    _selectedDietTag != null
                        ? kDietNameToTag[_selectedDietTag]
                        : null,
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
          _isBackgroundRefreshing = false;
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
      final list =
          _myRecipesOnly
              ? await _recipeService.getMyRecipes(
                sortBy: _sortBy == 'name' ? 'newest' : _sortBy,
                favoritesOnly: _favoritesOnly,
                newOnly: _newOnly,
                communityOnly: _communityOnly,
                search: _searchQuery,
                mealType: _selectedMealType,
                difficulty: _selectedDifficulty,
                tag:
                    _selectedDietTag != null
                        ? kDietNameToTag[_selectedDietTag]
                        : null,
                limit: _pageSize,
                skip: skip,
              )
              : await _recipeService.getRecipes(
                search: _searchQuery,
                mealType: _selectedMealType,
                difficulty: _selectedDifficulty,
                tag:
                    _selectedDietTag != null
                        ? kDietNameToTag[_selectedDietTag]
                        : null,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nie udało się wczytać kolejnych przepisów: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiAddRecipeScreen()),
                );
                _loadImportStatus();
              },
            ),
          // UWAGA (naprawa widoczności): zwykła, konturowa ikona ledwo
          // było widać na pasku — teraz wypełniona, w złotym kolorze
          // trofeum, na delikatnym tle, z subtelną animacją pulsowania,
          // żeby wyraźnie zachęcała do sprawdzenia cotygodniowego
          // konkursu, nie ginęła obok innych, zwykłych ikon.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                Icons.emoji_events_outlined,
                color: AppTheme.actionAccentColor,
              ),
              tooltip: 'Ranking autorów przepisów',
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RecipeLeaderboardScreen(),
                    ),
                  ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Nazwa, autor lub składnik...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isEmpty
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
          NestedScrollView(
            // UWAGA (naprawa): pasek filtrów przebudowany na SliverAppBar
            // (floating+snap) zamiast zwykłego Column — to standardowy
            // wzorzec Fluttera "chowaj przy przewijaniu w dół, pokaż od razu
            // przy najmniejszym przewinięciu w górę". Daje więcej miejsca na
            // siatkę przepisów, gdy użytkownik przegląda listę.
            headerSliverBuilder:
                (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildQuickToggle(
                            icon: Icons.favorite_border,
                            activeIcon: Icons.favorite,
                            label: 'Ulubione',
                            isActive: _favoritesOnly,
                            activeColor: AppTheme.actionPrimaryColor,
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
                            activeColor: AppTheme.actionPrimaryColor,
                            onTap: () {
                              setState(() => _myRecipesOnly = !_myRecipesOnly);
                              _loadRecipes();
                            },
                          ),
                          _buildQuickToggle(
                            icon: Icons.fiber_new_outlined,
                            activeIcon: Icons.fiber_new,
                            label: 'Nowości',
                            isActive: _newOnly,
                            activeColor: AppTheme.actionPrimaryColor,
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
                            activeColor: AppTheme.actionPrimaryColor,
                            onTap: () {
                              setState(() => _communityOnly = !_communityOnly);
                              _loadRecipes();
                            },
                          ),
                          ActionChip(
                            avatar: Icon(
                              Icons.tune,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                            label: Text(
                              _moreFiltersActiveCount == 0
                                  ? 'Filtry'
                                  : 'Filtry ($_moreFiltersActiveCount)',
                            ),
                            onPressed: () => _showFilterSheet(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            body:
                _isLoading && !_isBackgroundRefreshing
                    ? const Center(child: CircularProgressIndicator())
                    : _recipes.isEmpty
                    ? _buildEmptyState()
                    : CustomScrollView(
                      slivers: [
                        if (_isBackgroundRefreshing)
                          const SliverToBoxAdapter(
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _recipeColumnCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent:
                                      ((MediaQuery.sizeOf(context).width -
                                                  48 -
                                                  12 *
                                                      (_recipeColumnCount -
                                                          1)) /
                                              _recipeColumnCount) *
                                          .75 +
                                      136 *
                                          MediaQuery.textScalerOf(
                                            context,
                                          ).scale(14) /
                                          14,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildRecipeCard(_recipes[index]),
                              childCount: _recipes.length,
                            ),
                          ),
                        ),
                        if (_hasMore)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                12,
                                24,
                                96,
                              ),
                              child: OutlinedButton.icon(
                                onPressed: _isLoadingMore ? null : _loadMore,
                                icon:
                                    _isLoadingMore
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Icons.expand_more),
                                label: Text(
                                  _isLoadingMore
                                      ? 'Wczytywanie…'
                                      : 'Pokaż więcej przepisów',
                                ),
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

  Future<void> _showAddRecipeChoice(BuildContext context) async {
    final choice = await showModalBottomSheet<_AddRecipeChoice>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;

        Widget optionTile({
          required IconData icon,
          required String title,
          String? subtitle,
          Widget? trailing,
          required VoidCallback onTap,
        }) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: subtitle == null ? null : Text(subtitle),
                trailing: trailing,
                onTap: onTap,
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dodaj przepis',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Z pomocą AI',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  optionTile(
                    icon: Icons.photo_camera_outlined,
                    title: 'Zrób zdjęcie',
                    subtitle: 'Przepisu albo gotowego dania',
                    trailing: const PremiumFeatureTag(
                      label: 'PREMIUM · 2 PKT',
                      fontSize: 8,
                    ),
                    onTap:
                        () => Navigator.of(
                          sheetContext,
                        ).pop(_AddRecipeChoice.photo),
                  ),
                  optionTile(
                    icon: Icons.text_snippet_outlined,
                    title: 'Wklej tekst',
                    trailing: const PremiumFeatureTag(
                      label: 'PREMIUM · 2 PKT',
                      fontSize: 8,
                    ),
                    onTap:
                        () => Navigator.of(
                          sheetContext,
                        ).pop(_AddRecipeChoice.text),
                  ),
                  optionTile(
                    icon: Icons.link,
                    title: 'Wklej link',
                    trailing: const PremiumFeatureTag(
                      label: 'PREMIUM · 2 PKT',
                      fontSize: 8,
                    ),
                    onTap:
                        () => Navigator.of(
                          sheetContext,
                        ).pop(_AddRecipeChoice.link),
                  ),
                  const SizedBox(height: 8),
                  // Mniejsza, drugorzędna opcja ręczna.
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          () => Navigator.of(
                            sheetContext,
                          ).pop(_AddRecipeChoice.manual),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Dodaj ręcznie'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: colorScheme.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Najpierw czekamy, aż dolny panel całkowicie odda fokus, dopiero
    // potem otwieramy kolejny ekran. Wcześniejsze jednoczesne pop+push
    // zostawiało dwa aktywne FocusScope i na Androidzie mogło schować
    // klawiaturę już podczas wpisywania pierwszego pola.
    if (!mounted || !context.mounted || choice == null) return;
    late final Widget page;
    final isAi = choice != _AddRecipeChoice.manual;
    switch (choice) {
      case _AddRecipeChoice.photo:
        page = const AiAddRecipeScreen(initialTabIndex: 1);
        break;
      case _AddRecipeChoice.text:
        page = const AiAddRecipeScreen(initialTabIndex: 0);
        break;
      case _AddRecipeChoice.link:
        page = const AiAddRecipeScreen(initialTabIndex: 2);
        break;
      case _AddRecipeChoice.manual:
        page = const ManualAddRecipeScreen();
        break;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (isAi && mounted) _loadImportStatus();
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

  Widget _buildQuickToggle({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) => FilterChip(
    label: Text(label),
    labelStyle: TextStyle(
      color: AppTheme.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    avatar: Icon(
      isActive ? activeIcon : icon,
      size: 18,
      color: isActive ? activeColor : AppTheme.textSecondary,
    ),
    selected: isActive,
    showCheckmark: false,
    onSelected: (_) => onTap(),
  );

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
                          Text(
                            'Filtry',
                            style: Theme.of(sheetContext).textTheme.titleLarge,
                          ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry
                              in const {
                                'name': 'Alfabetycznie',
                                'kcal_asc': 'Kalorie: mniej',
                                'kcal_desc': 'Kalorie: więcej',
                                'prep_time': 'Czas: najszybsze',
                              }.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              selected: _sortBy == entry.key,
                              onSelected:
                                  (_) =>
                                      setSheetState(() => _sortBy = entry.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Dieta',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Wszystkie'),
                            selected: _selectedDietTag == null,
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedDietTag = null,
                                ),
                          ),
                          // Pomijamy "Bez ograniczeń" z kDietOptions — tutaj
                          // odpowiednikiem "braku filtra" jest opcja
                          // "Wszystkie" powyżej, więc zaczynamy od indeksu 1.
                          for (final diet in kDietOptions.skip(1))
                            ChoiceChip(
                              label: Text(diet['name']!),
                              selected: _selectedDietTag == diet['name'],
                              onSelected:
                                  (_) => setSheetState(
                                    () => _selectedDietTag = diet['name'],
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Typ posiłku',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Wszystkie'),
                            selected: _selectedMealType == null,
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedMealType = null,
                                ),
                          ),
                          ChoiceChip(
                            label: const Text('Śniadania'),
                            selected: _selectedMealType == 'śniadanie',
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedMealType = 'śniadanie',
                                ),
                          ),
                          ChoiceChip(
                            label: const Text('Obiady'),
                            selected: _selectedMealType == 'obiad',
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedMealType = 'obiad',
                                ),
                          ),
                          ChoiceChip(
                            label: const Text('Kolacje'),
                            selected: _selectedMealType == 'kolacja',
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedMealType = 'kolacja',
                                ),
                          ),
                          ChoiceChip(
                            label: const Text('Przekąski'),
                            selected: _selectedMealType == 'przekąska',
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedMealType = 'przekąska',
                                ),
                          ),
                          ChoiceChip(
                            label: const Text('Desery'),
                            selected: _selectedMealType == 'deser',
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedMealType = 'deser',
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Trudność',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Każda'),
                            selected: _selectedDifficulty == null,
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedDifficulty = null,
                                ),
                          ),
                          ChoiceChip(
                            label: const Text('Łatwe'),
                            selected: _selectedDifficulty == 'łatwy',
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedDifficulty = 'łatwy',
                                ),
                          ),
                          ChoiceChip(
                            label: const Text('Średnie'),
                            selected: _selectedDifficulty == 'średni',
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedDifficulty = 'średni',
                                ),
                          ),
                          ChoiceChip(
                            label: const Text('Trudne'),
                            selected: _selectedDifficulty == 'trudny',
                            onSelected:
                                (_) => setSheetState(
                                  () => _selectedDifficulty = 'trudny',
                                ),
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
    return RecipeLibraryCard(
      key: ValueKey(recipe.id),
      recipe: recipe,
      onTap: () async {
        await Navigator.of(
          context,
        ).pushNamed('/recipe/detail', arguments: recipe);
        if (mounted) _loadRecipes(preserveCurrent: true);
      },
    );
  }

  int get _recipeColumnCount {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 400 && MediaQuery.textScalerOf(context).scale(14) > 21)
      return 1;
    if (width >= 1000) return 4;
    if (width >= 680) return 3;
    return 2;
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
            'Sprawdź nazwę przepisu, autora lub składnika.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
