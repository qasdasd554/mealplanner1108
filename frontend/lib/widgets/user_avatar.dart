import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reużywalny awatar użytkownika. Pokazuje WŁASNE ZDJĘCIE, jeśli
/// użytkownik je ustawił, w przeciwnym razie jeden z dwóch gotowych
/// placeholderów ("male"/"female"), albo neutralną domyślną ikonę.
/// Używany wszędzie tam, gdzie pokazywany jest użytkownik: profil,
/// ranking autorów przepisów, komentarze, autorstwo przepisu.
///
/// UWAGA (naprawa — zła kolorystyka): wcześniejsza wersja używała
/// jaskrawego różowego/niebieskiego gradientu, który wizualnie mocno
/// "odznaczał się" na tle reszty aplikacji (paleta: Emerald Green,
/// Violet, Amber). Przeprojektowane na TEN SAM, stonowany wzorzec, który
/// już jest używany gdzie indziej w aplikacji (np. karty szybkich akcji
/// na ekranie głównym) — delikatne tło w kolorze marki (12% krycia) +
/// ikona w pełnym kolorze, zamiast krzykliwego, pełnego gradientu.
class UserAvatar extends StatelessWidget {
  final String? avatar;

  /// Własne zdjęcie profilowe, jako base64 — MA PIERWSZEŃSTWO przed
  /// ikoną z `avatar`, gdy oba są ustawione.
  final String? avatarPhotoBase64;

  final double size;
  final bool selected;

  const UserAvatar({
    super.key,
    required this.avatar,
    this.avatarPhotoBase64,
    this.size = 40,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarPhotoBase64 != null && avatarPhotoBase64!.isNotEmpty) {
      return _buildPhotoAvatar(avatarPhotoBase64!);
    }
    return _buildIconAvatar();
  }

  Widget _buildPhotoAvatar(String base64Photo) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(base64Photo);
    } catch (_) {
      // Uszkodzone dane — wracamy do ikony zamiast pokazać złamany
      // obrazek albo wywalić cały ekran.
      return _buildIconAvatar();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          width: selected ? 3 : 0,
        ),
        image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildIconAvatar() {
    final Color color;
    final IconData icon;
    switch (avatar) {
      case 'female':
        // Violet — drugi kolor marki, ten sam co reszta "kobiecych"/
        // wyróżniających akcentów gdzie indziej w aplikacji.
        color = AppTheme.secondaryColor;
        icon = Icons.woman;
        break;
      case 'male':
        // Emerald Green — główny kolor marki aplikacji.
        color = AppTheme.primaryColor;
        icon = Icons.man;
        break;
      default:
        color = AppTheme.textSecondary;
        icon = Icons.person;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.14),
        border: Border.all(
          color: selected ? AppTheme.primaryColor : color.withOpacity(0.25),
          width: selected ? 3 : 1,
        ),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}
