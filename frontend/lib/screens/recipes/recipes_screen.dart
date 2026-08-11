import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/recipe.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';

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
                _buildFilterChip('Śniadania 🌅', 'śniadanie', _selectedMealType == 'śniadanie', (val) {
                  setState(() {
                    _selectedMealType = 'śniadanie';
                  });
                  _loadRecipes();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Obiady ☀️', 'obiad', _selectedMealType == 'obiad', (val) {
                  setState(() {
                    _selectedMealType = 'obiad';
                  });
                  _loadRecipes();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Kolacje 🌙', 'kolacja', _selectedMealType == 'kolacja', (val) {
                  setState(() {
                    _selectedMealType = 'kolacja';
                  });
                  _loadRecipes();
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Przekąski 🍎', 'przekąska', _selectedMealType == 'przekąska', (val) {
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
        decoration: const BoxDecoration(
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
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.secondaryColor.withOpacity(0.3),
                      AppTheme.primaryColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    recipe.mealTypeEmoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
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
                          '⏱️ ${recipe.totalTimeMin} min • 🔥 ${recipe.nutritionTotal.kcal.toInt()} kcal',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
    return const Center(
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
