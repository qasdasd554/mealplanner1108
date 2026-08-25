import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reużywalny awatar użytkownika — pokazuje jeden z dwóch gotowych
/// placeholderów ("male"/"female") jako ikonę na delikatnym tle w
/// kolorze marki, albo neutralną domyślną ikonę, gdy użytkownik nie
/// wybrał jeszcze żadnego awatara. Używany zarówno w profilu (duży, do
/// wyboru), jak i w rankingu autorów przepisów (mały, tylko do
/// wyświetlenia).
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
  final double size;
  final bool selected;

  const UserAvatar({
    super.key,
    required this.avatar,
    this.size = 40,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
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
