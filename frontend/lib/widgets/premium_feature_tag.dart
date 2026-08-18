import 'package:flutter/material.dart';

/// Mały, złoty znacznik "Premium" do umieszczania OBOK przycisków/funkcji,
/// które wymagają subskrypcji — w odróżnieniu od [PremiumBadge] (który
/// pokazuje status KONTA), ten widget oznacza status FUNKCJI. Celowo
/// bardzo kompaktowy, żeby nie zdominować przycisku, który opisuje.
class PremiumFeatureTag extends StatelessWidget {
  final double fontSize;

  const PremiumFeatureTag({super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.6, vertical: fontSize * 0.15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5C24D), Color(0xFFE0A62E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(fontSize),
      ),
      child: Text(
        'PREMIUM',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
