import 'package:flutter/material.dart';
import '../../l10n/market_locale.dart';
import '../../l10n/recipe_content.dart';
import '../../l10n/catalog_labels.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:async';

import '../../models/recipe.dart';
import '../../models/meal_plan.dart';
import '../../models/premium_offer.dart';
import '../../services/recipe_service.dart';
import '../../services/shopping_list_service.dart';
import '../../services/recipe_comment_service.dart';
import '../../services/contextual_premium_offer_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/recipe_comments_section.dart';
import '../../widgets/recipe_favorite_button.dart';
import '../../widgets/recipe_approval_bar.dart';
import '../../widgets/dish_shopping_list_button.dart';
import '../../widgets/recipe_delete_button.dart';
import '../../widgets/recipe_publish_button.dart';
import '../../widgets/recipe_photo.dart';
import '../../widgets/report_block_menu.dart';
import '../../widgets/submit_recipe_photo_button.dart';
import '../../widgets/recipe_variant_editor_sheet.dart';
import '../../widgets/ai_recipe_edit_sheet.dart';
import '../../utils/quantity_formatter.dart';
import '../../utils/error_utils.dart';
import '../../providers/auth_provider.dart';

import 'package:provider/provider.dart';

import '../../widgets/user_avatar.dart';
import '../../widgets/tiktok_icon.dart';

class RecipeDetailScreen extends StatefulWidget {
  final RecipeService? service;
  final RecipeCommentService? commentService;
  final ShoppingListService? shoppingService;
  const RecipeDetailScreen({
    super.key,
    this.service,
    this.commentService,
    this.shoppingService,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final RecipeService _service = widget.service ?? RecipeService();
  final ScrollController _scrollController = ScrollController();
  Timer? _premiumOfferTimer;
  bool _viewedLongEnough = false;
  bool _premiumOfferAttempted = false;

  /// Przepis PRZEKAZANY z ekranu listy/siatki — wyświetlany od razu, bez
  /// czekania na sieć, żeby otwarcie szczegółów nie migało pustym ekranem.
  Recipe? _initialRecipe;
  int? _plannedServings;

  double _ingredientMultiplier(Recipe recipe) =>
      _plannedServings == null
          ? 1
          : _plannedServings! / (recipe.servings > 0 ? recipe.servings : 1);

  /// Full details still load once for ingredients, method and large photos.
  /// List summaries already include small public author fields, so this
  /// response does not insert a previously missing author section.
  Recipe? _freshRecipe;
  List<RecipeIngredient>? _temporaryIngredients;
  bool _isSavingVariant = false;
  bool _isRefreshingRecipe = false;
  bool _detailsLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_tryShowContextualPremiumOffer);
    _premiumOfferTimer = Timer(recipePremiumOfferDelay, () {
      _viewedLongEnough = true;
      _tryShowContextualPremiumOffer();
    });
  }

  void _tryShowContextualPremiumOffer() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    if (!shouldTriggerRecipePremiumOffer(
      viewedLongEnough: _viewedLongEnough,
      scrollOffset: _scrollController.offset,
      alreadyAttempted: _premiumOfferAttempted,
      isCurrentRoute: ModalRoute.of(context)?.isCurrent ?? false,
    )) {
      return;
    }
    _premiumOfferAttempted = true;
    ContextualPremiumOfferService.maybeShow(
      context,
      PremiumOfferContext.recipe,
    );
  }

  @override
  void dispose() {
    _premiumOfferTimer?.cancel();
    _scrollController
      ..removeListener(_tryShowContextualPremiumOffer)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialRecipe == null) {
      final arguments = ModalRoute.of(context)!.settings.arguments;
      if (arguments is MealPlanEntry) {
        _initialRecipe = arguments.recipe;
        _plannedServings = arguments.plannedServings;
      } else {
        _initialRecipe = arguments as Recipe;
      }
      _refreshFromServer();
    }
  }

  Future<void> _refreshFromServer() async {
    if (_isRefreshingRecipe) return;
    final requestedRecipeId = _initialRecipe!.id;
    if (mounted) {
      setState(() {
        _isRefreshingRecipe = true;
        _detailsLoadFailed = false;
      });
    }
    Recipe? fresh;
    try {
      fresh = await _service.getRecipe(requestedRecipeId);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isRefreshingRecipe = false;
      if (_initialRecipe?.id != requestedRecipeId) return;
      _detailsLoadFailed = fresh == null;
      if (fresh != null) _freshRecipe = fresh;
    });
  }

  Future<void> _openTikTokProfile(String username) async {
    final uri = Uri.https('www.tiktok.com', '/@$username');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.strings.detailTikTokFailed)),
        );
    }
  }

  Future<void> _editIngredients(Recipe recipe) async {
    if (_isSavingVariant) return;
    final changed = await showModalBottomSheet<List<RecipeIngredient>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => RecipeVariantEditorSheet(
            ingredients:
                (_temporaryIngredients ?? recipe.ingredients)
                    .map(
                      (ingredient) =>
                          ingredient.scaledBy(_ingredientMultiplier(recipe)),
                    )
                    .toList(),
          ),
    );
    if (changed == null || !mounted) return;
    setState(
      () =>
          _temporaryIngredients =
              changed
                  .map(
                    (ingredient) =>
                        ingredient.scaledBy(1 / _ingredientMultiplier(recipe)),
                  )
                  .toList(),
    );
  }

  Future<void> _editWithAi(Recipe recipe) async {
    final updated = await showAiRecipeEditSheet(
      context,
      recipe,
      service: _service,
    );
    if (updated == null || !mounted) return;
    setState(() {
      _initialRecipe = updated;
      _freshRecipe = updated;
      _temporaryIngredients = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.strings.detailAiUpdated)));
    _refreshFromServer();
  }

  Future<Recipe?> _saveVariant(Recipe source) async {
    final ingredients = _temporaryIngredients;
    if (ingredients == null || ingredients.isEmpty || _isSavingVariant)
      return null;

    setState(() => _isSavingVariant = true);
    try {
      final saved = await _service.saveVariant(source.id, ingredients);
      if (!mounted) return null;
      setState(() {
        _initialRecipe = saved;
        _freshRecipe = saved;
        _temporaryIngredients = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.strings.detailSavedVariant(saved.name)),
          ),
        );
      return saved;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(friendlyError(error, strings: context.strings)),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      return null;
    } finally {
      if (mounted) setState(() => _isSavingVariant = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _freshRecipe ?? _initialRecipe!;
    final displayedIngredients =
        (_temporaryIngredients ?? recipe.ingredients)
            .map(
              (ingredient) =>
                  ingredient.scaledBy(_ingredientMultiplier(recipe)),
            )
            .toList();

    // Legacy links/plan entries may not have the new light author preview.
    // Show a loading/retry state, never a finished-looking authorless page
    // which is then replaced when the one details request completes.
    if (_freshRecipe == null &&
        recipe.createdByUserId != null &&
        !recipe.createdByProfileLoaded &&
        recipe.createdByName == null) {
      return Scaffold(
        key: const Key('recipe-author-loading'),
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_detailsLoadFailed)
                    OutlinedButton.icon(
                      onPressed: _refreshFromServer,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.strings.detailRetry),
                    )
                  else ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      context.strings.detailLoading,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. Premium Hero AppBar — prawdziwe zdjęcie AI na pełną
          // szerokość, jeśli dostępne; w przeciwnym razie (przepis bez
          // zdjęcia) zachowujemy poprzednie traktowanie z ilustracją
          // kategorii na gradientowym tle.
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: RecipeFavoriteButton(
                  recipe: recipe,
                  activeColor: Colors.redAccent,
                ),
              ),
              // Zgłoś / Zablokuj — TYLKO dla przepisów dodanych przez
              // innego użytkownika (Guideline 1.2 Apple). Oficjalne
              // przepisy (createdByUserId == null) i WŁASNE przepisy
              // (isOwnRecipe) nie potrzebują tej opcji.
              if (recipe.createdByUserId != null && !recipe.isOwnRecipe)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ReportBlockMenu(
                    authorId: recipe.createdByUserId,
                    authorName: context.strings.detailRecipeAuthor,
                    onReport:
                        (reason, details) => Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).reportRecipe(
                          recipe.id,
                          reason: reason,
                          details: details,
                        ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              // UWAGA (naprawa — ten sam błąd co w karcie listy): sekcja
              // dubinowała logikę wyświetlania zdjęcia zamiast reużywać
              // RecipePhoto, i przy tym sprawdzała TYLKO realPhotoAsset —
              // całkowicie pomijając photoBase64. Przebudowane na
              // RecipePhoto (ta sama, poprawna logika fallbacku wszędzie
              // w aplikacji: realPhotoAsset -> photoBase64 ->
              // categoryImageAsset), więc plakietka "wygenerowane przez
              // AI" jest teraz też wbudowana w sam widget, bez dublowania.
              background: Stack(
                fit: StackFit.expand,
                children: [
                  RecipePhoto(recipe: recipe, showAiBadge: true),
                  // Delikatny gradient u dołu — poprawia czytelność
                  // przycisku "wstecz" i plakietki AI na jasnych zdjęciach.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.25),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                  // Znaczek "Nowość" — widoczny przez 14 dni od dodania,
                  // niezależnie od źródła (z zewnątrz czy od użytkownika).
                  if (recipe.isNew)
                    Positioned(
                      top: 50,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.strings.recipeNew,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 1b. Pasek akceptacji/odrzucenia — widoczny TYLKO adminom,
          // TYLKO gdy przepis czeka na akceptację (visibility="pending").
          // Sam widget zwraca pusty SizedBox we wszystkich innych
          // przypadkach, więc bezpiecznie wstawiamy go bezwarunkowo.
          SliverToBoxAdapter(child: RecipeApprovalBar(recipe: recipe)),

          // 1c. Przycisk "Lista zakupów na to danie" — funkcja Premium.
          // Sam widget zwraca pusty SizedBox dla kont bez dostępu premium.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DishShoppingListButton(
                recipe: recipe,
                servings: _plannedServings,
                service: widget.shoppingService,
                prepareRecipe:
                    () async =>
                        _temporaryIngredients == null
                            ? (_freshRecipe ?? _initialRecipe!)
                            : await _saveVariant(
                              _freshRecipe ?? _initialRecipe!,
                            ),
              ),
            ),
          ),

          // "Opublikuj przepis" — widoczny TYLKO dla właściciela
          // prywatnego przepisu. Zaraz nad "Usuń", żeby były razem.
          SliverToBoxAdapter(child: RecipePublishButton(recipe: recipe)),

          // "Usuń przepis" — widoczny TYLKO dla właściciela. Sam widget
          // zwraca pusty SizedBox dla cudzych/oficjalnych przepisów.
          SliverToBoxAdapter(child: RecipeDeleteButton(recipe: recipe)),

          if (recipe.isOwnRecipe && recipe.visibility == 'private')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: OutlinedButton.icon(
                  onPressed: () => _editWithAi(recipe),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(context.strings.detailAiAction),
                ),
              ),
            ),

          // 2. Karta z detalami przepisu
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Dodane przez [nazwa]" wraz z awatarem — PRZENIESIONE
                  // na sam początek (przed tagi i nazwę), na wyraźną
                  // prośbę: autorstwo ma być pierwszą informacją widoczną
                  // na ekranie przepisu, nie dopiskiem pod nazwą.
                  //
                  // Puste dla 137 oficjalnych przepisów dostarczonych
                  // z aplikacją (createdByName wtedy null) — dla nich ta
                  // sekcja się nie pokazuje wcale.
                  if (recipe.createdByName != null &&
                      recipe.createdByName!.isNotEmpty) ...[
                    Row(
                      children: [
                        UserAvatar(
                          avatar: recipe.createdByAvatar,
                          avatarPhotoBase64: recipe.createdByAvatarPhoto,
                          size: 40,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.strings.detailAddedBy(
                                  recipe.createdByName!,
                                ),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              if (recipe.hasCreatorTikTok)
                                TextButton(
                                  onPressed:
                                      () => _openTikTokProfile(
                                        recipe.createdByTikTokUsername!,
                                      ),
                                  style: TextButton.styleFrom(
                                    minimumSize: Size.zero,
                                    padding: const EdgeInsets.only(top: 2),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor:
                                        AppTheme.actionPrimaryColor,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const TikTokIcon(size: 15),
                                      const SizedBox(width: 5),
                                      Text(
                                        '@${recipe.createdByTikTokUsername}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(),
                    const SizedBox(height: 16),
                  ],

                  // Tagi
                  if (recipe.tags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          recipe.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                    ).animate().fadeIn(),

                  const SizedBox(height: 12),
                  // Nazwa przepisu
                  Text(
                    recipe.displayName(context),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 8),
                  // Opis
                  if (recipe.displayDescription(context) != null &&
                      recipe.displayDescription(context)!.isNotEmpty) ...[
                    Text(
                      recipe.displayDescription(context)!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 20),
                  ],

                  // Czas, Porcje, Trudność (Info Row)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildInfoColumn(
                            context,
                            context.strings.detailTime,
                            '${recipe.totalTimeMin} min',
                            icon: Icons.schedule,
                          ),
                        ),
                        _buildDivider(),
                        Expanded(
                          child: _buildInfoColumn(
                            context,
                            context.strings.detailServings,
                            '${_plannedServings ?? recipe.servings}',
                          ),
                        ),
                        _buildDivider(),
                        Expanded(
                          child: _buildInfoColumn(
                            context,
                            context.strings.recipeDifficulty,
                            context.strings.difficultyLabel(recipe.difficulty),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 24),

                  // Wartości odżywcze
                  Text(
                    context.strings.detailNutrition,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    context.strings.detailPerServing,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildNutritionGrid(recipe),
                  if (recipe.hasIncompleteNutrition ||
                      recipe.hasEstimatedNutrition) ...[
                    const SizedBox(height: 8),
                    Text(
                      recipe.hasIncompleteNutrition
                          ? '${context.strings.recipeNutritionPartial}${recipe.hasEstimatedNutrition ? '\n${context.strings.recipeNutritionEstimated}' : ''}'
                          : context.strings.recipeNutritionEstimated,
                      key: const ValueKey('recipe-nutrition-status'),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Zaproponowanie zdjęcia — trafia do moderacji, nie
                  // podmienia zdjęcia od razu (patrz komentarz w widgecie).
                  Center(
                    child: SubmitRecipePhotoButton(
                      recipeId: recipe.id,
                      recipeHasPhoto:
                          recipe.photoBase64 != null || recipe.imageUrl != null,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Składniki
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        context.strings.manualRecipeIngredients,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed:
                            _freshRecipe == null && recipe.ingredients.isEmpty
                                ? null
                                : () => _editIngredients(recipe),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(context.strings.detailChange),
                      ),
                    ],
                  ),
                  if (_isRefreshingRecipe &&
                      _freshRecipe == null &&
                      displayedIngredients.isEmpty) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 8),
                    Text(
                      context.strings.detailLoading,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ] else if (_detailsLoadFailed &&
                      _freshRecipe == null &&
                      displayedIngredients.isEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refreshFromServer,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.strings.detailRetry),
                    ),
                  ],
                  if (_temporaryIngredients != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.strings.detailTemporary,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.strings.detailTemporaryHelp,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              FilledButton.icon(
                                onPressed:
                                    _isSavingVariant
                                        ? null
                                        : () => _saveVariant(recipe),
                                icon:
                                    _isSavingVariant
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.bookmark_add_outlined,
                                        ),
                                label: Text(context.strings.detailSaveVariant),
                              ),
                              TextButton(
                                onPressed:
                                    () => setState(
                                      () => _temporaryIngredients = null,
                                    ),
                                child: Text(context.strings.detailUndo),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  if (recipe.hasIncompleteNutrition) ...[
                    Text(
                      '${context.strings.nutritionMissing}: ${recipe.missingNutritionIngredients.join(', ')}',
                      key: const ValueKey('recipe-missing-nutrition'),
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ...displayedIngredients.map((ing) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ing.displayName(context) ??
                                  context.strings.detailIngredient,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              '${formatQuantity(ing.quantity, ing.unit)} ${context.strings.unitLabel(ing.unit)}${ing.kcal != null
                                  ? ' (${ing.nutritionEstimated ? '~ ' : ''}${ing.kcal} kcal)'
                                  : recipe.missingNutritionIngredients.contains(ing.productName)
                                  ? '\n${context.strings.nutritionMissing}'
                                  : ''}',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 28),

                  // Lifehack odmierzania porcji makaronu bez wagi
                  // kuchennej — pokazuje się dla KAŻDEGO przepisu
                  // zawierającego makaron jako składnik.
                  if (recipe.containsPasta) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.strings.detailPastaTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.strings.detailPastaHelp,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Sposób przygotowania — wcześniej ta sekcja w ogóle nie
                  // istniała w aplikacji, mimo że backend/dane mogły
                  // zawierać instrukcje krok po kroku.
                  if (recipe.displayInstructions(context).isNotEmpty) ...[
                    if (_plannedServings != null &&
                        _ingredientMultiplier(recipe) != 1) ...[
                      Text(
                        context.strings.detailPlanPortionHelp(
                          _plannedServings!,
                          recipe.servings,
                        ),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      context.strings.detailMethod,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...recipe.displayInstructions(context).asMap().entries.map((
                      entry,
                    ) {
                      final stepNumber = entry.key + 1;
                      final stepText = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$stepNumber',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  stepText,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 28),

                  // ── Proponowane przyprawy (opcjonalne) ────────────
                  if (recipe.displaySeasonings(context).isNotEmpty) ...[
                    Text(
                      context.strings.detailAlsoAdd,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      context.strings.detailSeasoningHelp,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          recipe.displaySeasonings(context).map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  color: AppTheme.accentColor,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── Komentarze i zdjęcia (teraz w pełni działające) ──
                  RecipeCommentsSection(
                    recipeId: recipe.id,
                    service: widget.commentService,
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: AppTheme.textSecondary.withOpacity(0.2),
    );
  }

  Widget _buildNutritionGrid(Recipe recipe) {
    final nut = recipe.nutritionTotal;
    // Wartości odżywcze przeliczone NA PORCJĘ — recipe.nutritionTotal
    // przechowuje sumę dla całego przepisu (wszystkich porcji razem),
    // a to nie jest to, czego ktoś się spodziewa patrząc na "Kalorie"
    // przy jednym daniu (tak samo jak etykieta żywieniowa zawsze podaje
    // wartość na porcję, a nie na cały garnek).
    final servings = recipe.servings > 0 ? recipe.servings : 1;
    String value(String key, String unit) {
      if (recipe.hasIncompleteNutrition) {
        final subtotal = recipe.knownNutritionSubtotal?.knownValue(key);
        return subtotal != null && subtotal > 0
            ? '${recipe.hasEstimatedNutrition ? '~ ' : ''}≥ ${(subtotal / servings).round()} $unit'
            : '—';
      }
      final amount = nut.knownValue(key);
      return amount == null
          ? '—'
          : '${recipe.hasEstimatedNutrition ? '~ ' : ''}${(amount / servings).round()} $unit';
    }

    final list = [
      {
        'label': context.strings.productFormCalories,
        'val': value('kcal', 'kcal'),
        'color': AppTheme.accentColor,
      },
      {
        'label': context.strings.homeProtein,
        'val': value('protein', 'g'),
        'color': Colors.blue,
      },
      {
        'label': context.strings.diaryFat,
        'val': value('fat', 'g'),
        'color': Colors.orange,
      },
      {
        'label': context.strings.diaryCarbs,
        'val': value('carbs', 'g'),
        'color': AppTheme.primaryColor,
      },
      {
        'label': context.strings.detailFiber,
        'val': value('fiber', 'g'),
        'color': Colors.green,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;
        final labelStyle = DefaultTextStyle.of(
          context,
        ).style.merge(TextStyle(color: AppTheme.textSecondary, fontSize: 11));
        final valueStyle =
            Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ) ??
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
        double textHeight(String text, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.localeOf(context),
          )..layout(maxWidth: (tileWidth - 34).clamp(1.0, double.infinity));
          final height = painter.height;
          painter.dispose();
          return height;
        }

        final originalHeight = tileWidth / 2.2;
        var requiredHeight = originalHeight;
        for (final item in list) {
          final height =
              26 +
              textHeight(item['label'] as String, labelStyle) +
              2 +
              textHeight(item['val'] as String, valueStyle);
          if (height > requiredHeight) requiredHeight = height.ceilToDouble();
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            mainAxisExtent:
                requiredHeight > originalHeight ? requiredHeight : null,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            final color = item['color'] as Color;

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(color: color.withOpacity(0.2), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item['label'] as String, style: labelStyle),
                  const SizedBox(height: 2),
                  Text(
                    item['val'] as String,
                    style: valueStyle.copyWith(color: color),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
