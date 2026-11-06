import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mała, elegancka odznaka "Premium" — złota/bursztynowa plakietka
/// z koroną, do umieszczania obok nazwy użytkownika wszędzie tam, gdzie
/// warto pokazać status premium (profil, powitanie na ekranie głównym).
class PremiumBadge extends StatelessWidget {
  /// Rozmiar czcionki tekstu "Premium" — reszta (ikona, wypełnienie)
  /// skaluje się proporcjonalnie.
  final double fontSize;

  const PremiumBadge({super.key, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.premiumInk(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.7,
        vertical: fontSize * 0.25,
      ),
      decoration: BoxDecoration(
        color: AppTheme.premiumSurface(context),
        borderRadius: BorderRadius.circular(fontSize),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: fontSize * 1.2, color: ink),
          SizedBox(width: fontSize * 0.3),
          Text(
            'Premium',
            style: TextStyle(
              color: ink,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
