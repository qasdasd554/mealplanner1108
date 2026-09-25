import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/recipe.dart';

/// Pokazuje zdjęcie przepisu:
/// 1. Prawdziwe zdjęcie z zasobów aplikacji (81 oficjalnych przepisów),
/// 2. w jego braku — zdjęcie przesłane przez użytkownika,
/// 3. w ostateczności — ilustrację kategorii jako zapasową.
class RecipePhoto extends StatefulWidget {
  final Recipe recipe;
  final BorderRadius? borderRadius;

  /// Wyłącz na bardzo małych miniaturkach, gdzie tekst byłby nieczytelny.
  final bool showAiBadge;

  const RecipePhoto({
    super.key,
    required this.recipe,
    this.borderRadius,
    this.showAiBadge = true,
  });

  @override
  State<RecipePhoto> createState() => _RecipePhotoState();
}

class _RecipePhotoState extends State<RecipePhoto> {
  Uint8List? _userPhotoBytes;

  @override
  void initState() {
    super.initState();
    _decodeUserPhoto();
  }

  @override
  void didUpdateWidget(covariant RecipePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipe.photoBase64 != widget.recipe.photoBase64) {
      _decodeUserPhoto();
    }
  }

  void _decodeUserPhoto() {
    final encoded = widget.recipe.photoBase64;
    if (encoded == null || encoded.isEmpty) {
      _userPhotoBytes = null;
      return;
    }
    try {
      // Base64 dekodujemy tylko po zmianie zdjęcia, a nie przy każdym
      // przebudowaniu kafelka podczas przewijania listy.
      _userPhotoBytes = base64Decode(encoded);
    } on FormatException {
      _userPhotoBytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final realPhoto = widget.recipe.realPhotoAsset;
    final radius = widget.borderRadius ?? BorderRadius.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth = constraints.maxWidth;
        final cacheWidth =
            logicalWidth.isFinite && logicalWidth > 0
                ? (logicalWidth * MediaQuery.devicePixelRatioOf(context))
                        .ceil()
                        .clamp(1, 1600)
                    as int
                : null;

        Widget fallback() => Center(
          child: SvgPicture.asset(
            widget.recipe.categoryImageAsset,
            width: 64,
            height: 64,
          ),
        );

        Widget image;
        if (realPhoto != null) {
          image = Image.asset(
            realPhoto,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: cacheWidth,
            errorBuilder: (context, error, stackTrace) => fallback(),
          );
        } else if (_userPhotoBytes != null) {
          image = Image.memory(
            _userPhotoBytes!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: cacheWidth,
            errorBuilder: (context, error, stackTrace) => fallback(),
          );
        } else {
          image = fallback();
        }

        return ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (realPhoto != null && widget.showAiBadge)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Opacity(
                      opacity: 0.5,
                      child: Text(
                        'Zdjęcie poglądowe, wygenerowane przez AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
