import 'package:flutter/material.dart';
import '../../data/cooking_tips.dart';
import '../../theme/app_theme.dart';

/// Pełna, przewijana lista wszystkich porad kulinarnych — otwierana po
/// dotknięciu karty "Porada dnia" na ekranie głównym.
class CookingTipsScreen extends StatelessWidget {
  const CookingTipsScreen({super.key});

  IconData _iconFor(IconIndex icon) {
    switch (icon) {
      case IconIndex.pasta:
        return Icons.ramen_dining_outlined;
      case IconIndex.vegetable:
        return Icons.eco_outlined;
      case IconIndex.meat:
        return Icons.set_meal_outlined;
      case IconIndex.baking:
        return Icons.cake_outlined;
      case IconIndex.storage:
        return Icons.kitchen_outlined;
      case IconIndex.general:
        return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Porady kulinarne')),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: kCookingTips.length,
          itemBuilder: (context, index) {
            final tip = kCookingTips[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_iconFor(tip.icon), color: AppTheme.secondaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tip.tip,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
