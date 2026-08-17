import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

/// Przycisk serca (dodaj/usuń z ulubionych) — samodzielny widget z własnym
/// stanem, żeby dotknięcie od razu odświeżało samo siebie bez przebudowy
/// całego (często dużego) ekranu, na którym się znajduje.
class RecipeFavoriteButton extends StatefulWidget {
  final Recipe recipe;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;

  const RecipeFavoriteButton({
    super.key,
    required this.recipe,
    this.activeColor,
    this.inactiveColor,
    this.size = 24,
  });

  @override
  State<RecipeFavoriteButton> createState() => _RecipeFavoriteButtonState();
}

class _RecipeFavoriteButtonState extends State<RecipeFavoriteButton> {
  final RecipeService _service = RecipeService();
  late bool _isFavorite;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.recipe.isFavorite;
  }

  @override
  void didUpdateWidget(RecipeFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // UWAGA (naprawa): jeśli Flutter odzyska ten sam obiekt stanu dla
    // INNEGO przepisu (np. brak klucza w liście nadrzędnej, przy zmianie
    // filtrów) — bez tego przycisk pokazywałby stan ulubionych z
    // POPRZEDNIEGO przepisu, bo initState() uruchamia się tylko raz.
    // Klucz w GridView (patrz recipes_screen.dart) to naprawia u źródła,
    // ale to dodatkowa warstwa zabezpieczenia, gdyby ktoś użył tego
    // widgetu gdzie indziej bez klucza.
    if (oldWidget.recipe.id != widget.recipe.id) {
      _isFavorite = widget.recipe.isFavorite;
    }
  }

  Future<void> _toggle() async {
    if (_isBusy) return;
    final previous = _isFavorite;
    // Optymistyczna aktualizacja — reaguje natychmiast, bez czekania na
    // odpowiedź serwera.
    setState(() {
      _isFavorite = !previous;
      _isBusy = true;
    });
    widget.recipe.isFavorite = _isFavorite;

    try {
      if (_isFavorite) {
        await _service.addFavorite(widget.recipe.id);
      } else {
        await _service.removeFavorite(widget.recipe.id);
      }
    } catch (e) {
      // Cofnij, jeśli serwer nie potwierdził.
      if (!mounted) return;
      setState(() => _isFavorite = previous);
      widget.recipe.isFavorite = previous;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się zaktualizować ulubionych')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _toggle,
      icon: Icon(
        _isFavorite ? Icons.favorite : Icons.favorite_border,
        color: _isFavorite ? (widget.activeColor ?? Colors.redAccent) : widget.inactiveColor,
        size: widget.size,
      ),
      tooltip: _isFavorite ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
    );
  }
}
