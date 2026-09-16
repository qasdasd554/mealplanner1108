import 'package:flutter/material.dart';
import '../../data/cooking_tips.dart';
import '../../theme/app_theme.dart';

/// Pełna, przewijana lista wszystkich porad kulinarnych — otwierana po
/// dotknięciu karty "Porada dnia" na ekranie głównym.
class CookingTipsScreen extends StatefulWidget {
  /// Indeks porady, do której ekran ma się przewinąć zaraz po otwarciu
  /// i którą podświetli. Ustawiany, gdy użytkownik dotknie karty
  /// "Porada dnia" — wcześniej trafiał na początek listy i musiał sam
  /// szukać tej, którą przed chwilą przeczytał na ekranie głównym.
  final int? highlightIndex;

  const CookingTipsScreen({super.key, this.highlightIndex});

  @override
  State<CookingTipsScreen> createState() => _CookingTipsScreenState();
}

class _CookingTipsScreenState extends State<CookingTipsScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Podświetlenie gaśnie samo po chwili — ma zwrócić uwagę na właściwą
  /// pozycję, a nie zostać na stałe.
  bool _highlightVisible = false;

  @override
  void initState() {
    super.initState();
    final index = widget.highlightIndex;
    if (index == null || index < 0 || index >= kCookingTips.length) return;

    _highlightVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      // Wysokość karty jest zmienna (różna długość tekstu), więc
      // przewijamy do PRZYBLIŻONEJ pozycji zamiast liczyć dokładnie —
      // przy podświetleniu i tak od razu widać, o którą chodzi.
      final offset = (index * 108.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightVisible = false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: kCookingTips.length,
          itemBuilder: (context, index) {
            final tip = kCookingTips[index];
            final isHighlighted =
                _highlightVisible && index == widget.highlightIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isHighlighted
                        ? AppTheme.secondaryColor.withOpacity(0.12)
                        : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isHighlighted
                          ? AppTheme.secondaryColor
                          : Colors.transparent,
                  width: 2,
                ),
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
                    child: Icon(
                      _iconFor(tip.icon),
                      color: AppTheme.secondaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tip.tip,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
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
