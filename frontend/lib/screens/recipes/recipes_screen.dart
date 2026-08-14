import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/recipe_favorite_button.dart';
import 'coming_soon_add_recipe_screen.dart';

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
      final list = await _recipeService.getRecipes(
        search: _searchQuery,
        mealType: _selectedMealType,
        difficulty: _selectedDifficulty,
        favoritesOnly: _favoritesOnly,
      );
      setState(() {
        _recipes = list;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Błąd podczas pobierania przepisów: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Przepisy'),
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
      body: Column(
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
                _buildFilterChip('Śniadania', 'śniadanie', _selectedMealType == 'śniadanie', (val) {
                  setState(() {
                    _selectedMealType = 'śniadanie';
                  });
                  _loadRecipes();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Obiady', 'obiad', _selectedMealType == 'obiad', (val) {
                  setState(() {
                    _selectedMealType = 'obiad';
                  });
                  _loadRecipes();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Kolacje', 'kolacja', _selectedMealType == 'kolacja', (val) {
                  setState(() {
                    _selectedMealType = 'kolacja';
                  });
                  _loadRecipes();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Przekąski', 'przekąska', _selectedMealType == 'przekąska', (val) {
                  setState(() {
                    _selectedMealType = 'przekąska';
                  });
                  _loadRecipes();
                }),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: AppTheme.textSecondary.withOpacity(0.2)),
                const SizedBox(width: 12),
                // Ulubione — osobno wyróżnione (nie jest to filtr typu
                // posiłku, tylko przełącznik "pokaż tylko to, co lubię").
                FilterChip(
                  label: const Text('Ulubione'),
                  avatar: Icon(
                    _favoritesOnly ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: _favoritesOnly ? Colors.white : Colors.redAccent,
                  ),
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
                const SizedBox(width: 8),
                _buildFilterChip('Łatwe', 'łatwy', _selectedDifficulty == 'łatwy', (val) {
                  setState(() {
                    _selectedDifficulty = 'łatwy';
                  });
                  _loadRecipes();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Średnie', 'średni', _selectedDifficulty == 'średni', (val) {
                  setState(() {
                    _selectedDifficulty = 'średni';
                  });
                  _loadRecipes();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Trudne', 'trudny', _selectedDifficulty == 'trudny', (val) {
                  setState(() {
                    _selectedDifficulty = 'trudny';
                  });
                  _loadRecipes();
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Grid przepisów
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recipes.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Wyszarzony celowo — funkcja jest zapowiedziana, ale jeszcze
        // nieaktywna. Dotknięcie pokazuje ekran z wyjaśnieniem, co będzie
        // można zrobić, zamiast udawać, że coś już działa.
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ComingSoonAddRecipeScreen()),
          );
        },
        backgroundColor: Colors.grey.shade400,
        foregroundColor: Colors.white,
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
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
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
      onTap: () {
        Navigator.of(context).pushNamed(
          '/recipe/detail',
          arguments: recipe,
        );
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
                    child: recipe.realPhotoAsset != null
                        // Plakietka "wygenerowane przez AI" pokazuje się TYLKO
                        // po wejściu w szczegóły przepisu — na miniaturce listy
                        // byłaby zbędnym szumem wizualnym na każdej karcie naraz.
                        ? RecipePhoto(recipe: recipe, showAiBadge: false)
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.secondaryColor.withOpacity(0.15),
                                  AppTheme.primaryColor.withOpacity(0.06),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: SvgPicture.asset(
                                  recipe.categoryImageAsset,
                                  width: 64,
                                  height: 64,
                                ),
                              ),
                      ),
                    ),
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
