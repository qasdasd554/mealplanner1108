import 'package:flutter/material.dart';

/// Spójne, złote obramowanie dla KAŻDEGO elementu interfejsu wymagającego
/// subskrypcji Premium — jeden wspólny widget, żeby to oznaczenie
/// wyglądało identycznie wszędzie w aplikacji (przyciski, karty, sekcje),
/// zamiast każdy ekran wymyślał to na nowo osobno.
///
/// Ten sam gradient co [PremiumFeatureTag] (#F5C24D → #E0A62E), więc oba
/// oznaczenia razem tworzą jedną, spójną "złotą" tożsamość wizualną dla
/// wszystkiego, co Premium w tej aplikacji.
///
/// UWAGA (celowa prostota): Flutter nie ma wbudowanego "obramowania z
/// gradientem" — zamiast pisać własną klasę BoxBorder z niestandardowym
/// malowaniem (ryzykowne, trudne do przetestowania bez realnego builda),
/// używamy standardowego, dobrze znanego wzorca: zewnętrzny kontener z
/// gradientowym tłem + wewnętrzny kontener z wypełnieniem w kolorze tła,
/// który "odsłania" tylko brzeg zewnętrznego gradientu jako ramkę.
class PremiumGoldBorder extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final Color? backgroundColor;

  const PremiumGoldBorder({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.borderWidth = 1.5,
    this.backgroundColor,
  });

  static const List<Color> goldGradient = [Color(0xFFF5C24D), Color(0xFFE0A62E)];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: goldGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: EdgeInsets.all(borderWidth),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(borderRadius - borderWidth),
        ),
        child: child,
      ),
    );
  }
}
