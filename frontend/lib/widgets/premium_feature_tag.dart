import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Mały, złoty znacznik "Premium" do umieszczania OBOK przycisków/funkcji,
/// które wymagają subskrypcji — w odróżnieniu od [PremiumBadge] (który
/// pokazuje status KONTA), ten widget oznacza status FUNKCJI. Celowo
/// bardzo kompaktowy, żeby nie zdominować przycisku, który opisuje.
class PremiumFeatureTag extends StatelessWidget {
  final double fontSize;
  final String label;

  const PremiumFeatureTag({
    super.key,
    this.fontSize = 10,
    this.label = 'PREMIUM',
  });

  @override
  Widget build(BuildContext context) {
    final ink =
        AppTheme.isDark ? const Color(0xFFFBBF24) : const Color(0xFF865500);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.65,
        vertical: fontSize * 0.28,
      ),
      decoration: BoxDecoration(
        color: AppTheme.accentTintColor,
        border: Border.all(color: AppTheme.actionAccentColor.withOpacity(0.55)),
        borderRadius: BorderRadius.circular(fontSize),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: fontSize * 0.9, color: ink),
          SizedBox(width: fontSize * 0.3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: ink,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
