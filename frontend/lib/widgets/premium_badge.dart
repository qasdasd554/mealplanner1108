import 'package:flutter/material.dart';

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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7, vertical: fontSize * 0.25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5C24D), Color(0xFFE0A62E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(fontSize),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0A62E).withOpacity(0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: fontSize * 1.2, color: Colors.white),
          SizedBox(width: fontSize * 0.3),
          Text(
            'Premium',
            style: TextStyle(
              color: Colors.white,
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
