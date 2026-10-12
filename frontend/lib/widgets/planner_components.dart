import 'package:flutter/material.dart';

import '../models/premium_offer.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import 'premium_feature_tag.dart';
import 'recipe_favorite_button.dart';
import 'recipe_photo.dart';

/// A bookmark is the recurring visual cue for sections of the planner.
class PlannerSectionHeading extends StatelessWidget {
  const PlannerSectionHeading({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 3,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.actionPrimaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

class PlannerQuickAction extends StatelessWidget {
  const PlannerQuickAction({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surfaceColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppTheme.outlineColor.withValues(alpha: .45)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 104),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 23, color: AppTheme.textSecondary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Only four shortcuts use intrinsic height; long labels can grow together.
class PlannerQuickActionGrid extends StatelessWidget {
  const PlannerQuickActionGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < children.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 12),
              Expanded(
                child:
                    i + 1 < children.length
                        ? children[i + 1]
                        : const SizedBox(),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

/// Recipe images lead the library; metadata is kept on separate lines.
class RecipeLibraryCard extends StatelessWidget {
  const RecipeLibraryCard({
    super.key,
    required this.recipe,
    required this.onTap,
  });

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surfaceColor,
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RecipePhoto(recipe: recipe, showAiBadge: false),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: const Color(0xB320242B),
                    shape: const CircleBorder(),
                    child: RecipeFavoriteButton(
                      recipe: recipe,
                      activeColor: Colors.redAccent,
                      inactiveColor: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                if (recipe.isNew)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Nowość',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${recipe.totalTimeMin} min · ${recipe.difficulty}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${(recipe.nutritionTotal.kcal / (recipe.servings > 0 ? recipe.servings : 1)).round()} kcal / porcję',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.actionPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// An inspectable benefit selector instead of another unsolicited modal.
class PremiumBenefitPreview extends StatefulWidget {
  const PremiumBenefitPreview({super.key});

  @override
  State<PremiumBenefitPreview> createState() => _PremiumBenefitPreviewState();
}

class PremiumPlanCard extends StatelessWidget {
  const PremiumPlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.period,
    required this.onTap,
    this.highlight = false,
    this.hasTrial = false,
    this.badge,
    this.campaign,
    this.processing = false,
  });

  final String title;
  final String price;
  final String period;
  final VoidCallback? onTap;
  final bool highlight;
  final bool hasTrial;
  final String? badge;
  final Widget? campaign;
  final bool processing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color:
          highlight
              ? (AppTheme.isDark
                  ? const Color(0xFF173B35)
                  : const Color(0xFFECFDF5))
              : AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color:
            highlight
                ? AppTheme.actionPrimaryColor
                : AppTheme.outlineColor.withValues(alpha: .55),
        width: highlight ? 1.5 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (badge != null) ...[
          Text(
            badge!,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (campaign != null) ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: campaign!),
        ],
        const SizedBox(height: 10),
        Text(
          hasTrial ? 'Testuj przez 7 dni za 0 zł' : '$price $period',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontSize: hasTrial ? 22 : 24,
          ),
        ),
        if (hasTrial) ...[
          const SizedBox(height: 6),
          Text(
            'Potem $price miesięcznie',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Dla kont uprawnionych do okresu próbnego. Subskrypcja odnawia się '
            'automatycznie. Możesz anulować ją w ustawieniach sklepu.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onTap,
          child:
              processing
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                  : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      hasTrial ? 'Sprawdź 7 dni za 0 zł' : 'Wybierz ten plan',
                      textAlign: TextAlign.center,
                    ),
                  ),
        ),
      ],
    ),
  );
}

class DiaryEnergySummary extends StatelessWidget {
  const DiaryEnergySummary({
    super.key,
    required this.consumed,
    required this.target,
    this.burned = 0,
  });

  final double consumed;
  final double target;
  final double burned;

  @override
  Widget build(BuildContext context) {
    final exceeded = consumed > target;
    final difference = (target - consumed).abs();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bilans kalorii',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${difference.round()} kcal',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 30,
                  color: exceeded ? AppTheme.errorColor : AppTheme.textPrimary,
                ),
              ),
              Text(
                exceeded ? 'powyżej celu' : 'do dziennego celu',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0,
            minHeight: 7,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: AppTheme.primaryTintColor,
            color: exceeded ? AppTheme.errorColor : AppTheme.actionPrimaryColor,
          ),
          const SizedBox(height: 10),
          Text(
            'Zjedzono ${consumed.round()} / ${target.round()} kcal',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          if (burned > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Cel obejmuje ${burned.round()} kcal z aktywności',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class DiaryEntryRow extends StatelessWidget {
  const DiaryEntryRow({
    super.key,
    required this.name,
    required this.amount,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final String amount;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onEdit,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Usuń z Dziennika',
                icon: Icon(
                  Icons.delete_outline,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  amount,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Zmień ilość lub składniki',
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                '${calories.round()} kcal',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'B ${protein.round()} g',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              Text(
                'W ${carbs.round()} g',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              Text(
                'T ${fat.round()} g',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PremiumBenefitPreviewState extends State<PremiumBenefitPreview> {
  PremiumOfferContext _selected = PremiumOfferContext.recipe;

  static const _choices = {
    PremiumOfferContext.recipe: ('Przepisy AI', Icons.menu_book_outlined),
    PremiumOfferContext.barcodeScanner: ('Skanowanie', Icons.qr_code_scanner),
    PremiumOfferContext.mealPlan: ('Planowanie', Icons.calendar_month_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final copy = PremiumOfferCopy.forContext(_selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumFeatureTag(fontSize: 11),
        const SizedBox(height: 12),
        Text(
          'Co ułatwi Ci Premium?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _choices.entries
                  .map(
                    (entry) => ChoiceChip(
                      label: Text(entry.value.$1),
                      avatar: Icon(
                        entry.value.$2,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                      selected: entry.key == _selected,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _selected = entry.key),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 18),
        Text(copy.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          copy.description,
          style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 12),
        ...copy.benefits.map(
          (benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_rounded,
                  color: AppTheme.actionPrimaryColor,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(benefit, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
