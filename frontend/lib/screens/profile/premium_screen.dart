import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

/// Ekran prezentacji subskrypcji Premium — lista korzyści + przyciski
/// zakupu. UWAGA: prawdziwe płatności (Google Play Billing) nie są
/// jeszcze podłączone, więc przyciski celowo NIE udają działającego
/// zakupu — pokazują uczciwą informację "wkrótce dostępne" zamiast
/// pretendować, że coś kupują, skoro nic by się nie stało.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const List<_PremiumFeature> _features = [
    _PremiumFeature(
      icon: Icons.all_inclusive,
      title: 'Plany posiłków bez limitu',
      description: 'Generuj tyle planów, ile chcesz — bez dziennego ograniczenia.',
    ),
    _PremiumFeature(
      icon: Icons.auto_awesome,
      title: 'Przepisy rozpoznawane przez AI',
      description: 'Dodawaj własne przepisy z wklejonego tekstu albo zdjęcia.',
    ),
    _PremiumFeature(
      icon: Icons.history,
      title: 'Pełna historia śledzenia',
      description: 'Przeglądaj całą historię kalorii, bez limitu 30 dni wstecz.',
    ),
    _PremiumFeature(
      icon: Icons.calendar_view_week,
      title: 'Wiele planów naraz',
      description: 'Osobny plan na dni robocze i osobny na weekend — jednocześnie.',
    ),
  ];

  void _showComingSoonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.hourglass_top_rounded, color: AppTheme.secondaryColor, size: 32),
        title: const Text('Już wkrótce'),
        content: const Text(
          'Płatności w aplikacji są w trakcie podłączania (Google Play). '
          'Ta funkcja pojawi się tu, gdy tylko będzie gotowa.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Rozumiem'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6D28D9), Color(0xFFE0A62E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 40),
                      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 12),
                      const Text(
                        'Meal Planner Premium',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: 4),
                      Text(
                        'Więcej możliwości dla Twojej kuchni',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                      ).animate().fadeIn(delay: 250.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ..._features.asMap().entries.map((entry) {
                  final index = entry.key;
                  final feature = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(feature.icon, color: AppTheme.secondaryColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feature.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                feature.description,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (300 + index * 100).ms).slideX(begin: 0.05, end: 0);
                }),
                const SizedBox(height: 12),
                _buildPricingCard(
                  context: context,
                  title: 'Miesięcznie',
                  price: '14,99 zł',
                  period: '/ miesiąc',
                  highlight: false,
                ).animate().fadeIn(delay: 700.ms),
                const SizedBox(height: 12),
                _buildPricingCard(
                  context: context,
                  title: 'Rocznie',
                  price: '119,99 zł',
                  period: '/ rok',
                  badge: 'Oszczędzasz 33%',
                  highlight: true,
                ).animate().fadeIn(delay: 800.ms),
                const SizedBox(height: 20),
                Text(
                  'Ceny przykładowe — subskrypcję można anulować w dowolnym momencie.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard({
    required BuildContext context,
    required String title,
    required String price,
    required String period,
    String? badge,
    required bool highlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: highlight
            ? const LinearGradient(
                colors: [Color(0xFFF5C24D), Color(0xFFE0A62E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: highlight ? null : AppTheme.surfaceColor,
        border: highlight ? null : Border.all(color: AppTheme.textSecondary.withOpacity(0.15)),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: const Color(0xFFE0A62E).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: highlight ? Colors.white : null,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: price,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: highlight ? Colors.white : AppTheme.primaryColor,
                          ),
                        ),
                        TextSpan(
                          text: ' $period',
                          style: TextStyle(
                            fontSize: 13,
                            color: highlight ? Colors.white.withOpacity(0.85) : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _showComingSoonDialog(context),
                style: highlight
                    ? ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFE0A62E),
                        minimumSize: const Size(110, 44),
                      )
                    : ElevatedButton.styleFrom(minimumSize: const Size(110, 44)),
                child: const Text('Kup Premium'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumFeature {
  final IconData icon;
  final String title;
  final String description;

  const _PremiumFeature({required this.icon, required this.title, required this.description});
}
