import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/recipe.dart';

/// Pokazuje zdjęcie przepisu:
/// 1. Prawdziwe zdjęcie z zasobów aplikacji (81 oficjalnych przepisów),
/// 2. w jego braku — zdjęcie przesłane przez użytkownika (ręcznie dodany
///    przepis albo rozpoznany ze zdjęcia przez AI), bez plakietki "AI"
///    (to prawdziwe zdjęcie, nie wygenerowane),
/// 3. w ostateczności — ilustrację kategorii jako zapasową.
///
/// Prawdziwe zdjęcia z pkt 1 mają zawsze widoczną plakietkę "Zdjęcie
/// poglądowe, wygenerowane przez AI" w prawym dolnym rogu — to element
/// interfejsu (nie wypalony w pikselach obrazu), więc tekst zawsze jest
/// czytelny i poprawnie napisany, niezależnie od tego, jak dobrze
/// narzędzie graficzne radzi sobie z renderowaniem tekstu.
class RecipePhoto extends StatelessWidget {
  final Recipe recipe;
  final BorderRadius? borderRadius;

  /// Czy pokazywać plakietkę AI — domyślnie tak przy prawdziwym zdjęciu.
  /// Wyłącz na bardzo małych miniaturkach (np. <60px), gdzie tekst i tak
  /// byłby nieczytelny — w takim wypadku lepiej go w ogóle nie pokazywać
  /// niż pokazać nieczytelny bełkot.
  final bool showAiBadge;

  const RecipePhoto({
    super.key,
    required this.recipe,
    this.borderRadius,
    this.showAiBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final realPhoto = recipe.realPhotoAsset;
    final userPhoto = recipe.photoBase64;
    final radius = borderRadius ?? BorderRadius.zero;

    Widget image;
    if (realPhoto != null) {
      image = Image.asset(
        realPhoto,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        // Gdyby plik jednak nie zaladowal sie poprawnie (np. blad przy
        // buildzie), pokaz ilustracje kategorii zamiast pustego/czerwonego
        // ekranu bledu.
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: SvgPicture.asset(recipe.categoryImageAsset, width: 64, height: 64),
          );
        },
      );
    } else if (userPhoto != null && userPhoto.isNotEmpty) {
      image = Image.memory(
        base64Decode(userPhoto),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: SvgPicture.asset(recipe.categoryImageAsset, width: 64, height: 64),
          );
        },
      );
    } else {
      image = Center(
        child: SvgPicture.asset(recipe.categoryImageAsset, width: 64, height: 64),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (realPhoto != null && showAiBadge)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                // Tło plakietki zostaje wyraźne (kontrast na każdym
                // zdjęciu) — tylko sam tekst jest przezroczysty w 50%.
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Opacity(
                  opacity: 0.5,
                  child: const Text(
                    'Zdjęcie poglądowe, wygenerowane przez AI',
                    style: TextStyle(color: Colors.white, fontSize: 8, height: 1.1),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
