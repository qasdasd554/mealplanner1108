import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';

/// Ekran pokazywany raz, zaraz po ukończeniu onboardingu — informuje
/// o punktach powitalnych.
///
/// Osobny ekran, a nie pasek komunikatu: to pierwsze zetknięcie
/// użytkownika z walutą aplikacji i jedyny moment, w którym da się
/// spokojnie wyjaśnić, do czego te punkty służą. Pasek zniknąłby po
/// kilku sekundach, zanim ktokolwiek zdążyłby przeczytać.
class WelcomeBonusScreen extends StatelessWidget {
  final int points;

  const WelcomeBonusScreen({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE0A62E);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: gold.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.card_giftcard,
                        size: 58,
                        color: gold,
                      ),
                    )
                    .animate()
                    .scale(duration: 450.ms, curve: Curves.easeOutBack)
                    .then()
                    .shimmer(duration: 900.ms, color: gold.withOpacity(0.5)),
                const SizedBox(height: 28),
                Text(
                  'Wszystko gotowe!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 10),
                Text(
                  'Na start dorzucamy Ci $points punkty premium — '
                  'to nasze podziękowanie za założenie konta '
                  'i skonfigurowanie aplikacji.',
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 350.ms),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: gold.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: gold, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Za 2 punkty dodasz przepis z dowolnego linku '
                          'lub zdjęcia — zrobi to za Ciebie AI.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 34),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        () =>
                            Navigator.of(context).pushReplacementNamed('/home'),
                    child: const Text('Zaczynamy'),
                  ),
                ).animate().fadeIn(delay: 650.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
