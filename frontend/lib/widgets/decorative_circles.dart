import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Cztery rozmyte, półprzezroczyste okręgi w tle, w odcieniach palety
/// marki (fioletowy, zielony, bursztynowy, drugi fioletowy) — ten sam
/// wzór, który był wcześniej tylko na ekranie logowania, teraz spójnie
/// dostępny wszędzie.
///
/// UŻYCIE: umieść jako PIERWSZE (najniższe) dziecko Stack, przed
/// właściwą treścią ekranu:
///   body: Stack(
///     children: [
///       const DecorativeCircles(),
///       SafeArea(child: ...),  // prawdziwa treść ekranu
///     ],
///   ),
///
/// Wewnętrzny Stack nie ma żadnych "nie-pozycjonowanych" dzieci (same
/// Positioned), więc Flutter automatycznie rozciąga go na całą dostępną
/// przestrzeń rodzica — nie trzeba dodatkowo owijać w Positioned.fill.
/// Opakowane w IgnorePointer, żeby dekoracja nigdy nie przechwytywała
/// dotknięć przeznaczonych dla treści nad nią.
class DecorativeCircles extends StatelessWidget {
  const DecorativeCircles({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryColor.withOpacity(0.15),
              ),
            ).animate().fadeIn(duration: 1000.ms).scale(duration: 1000.ms),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.12),
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 1000.ms).scale(duration: 1000.ms),
          ),
          Positioned(
            top: 160,
            left: -60,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentColor.withOpacity(0.12),
              ),
            ).animate(delay: 400.ms).fadeIn(duration: 1000.ms).scale(duration: 1000.ms),
          ),
          Positioned(
            bottom: 80,
            right: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.secondaryColor.withOpacity(0.08),
              ),
            ).animate(delay: 600.ms).fadeIn(duration: 1000.ms).scale(duration: 1000.ms),
          ),
        ],
      ),
    );
  }
}
