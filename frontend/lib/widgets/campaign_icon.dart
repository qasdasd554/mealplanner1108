import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ikona istniejącego pakietu z czytelną szarfą promocyjną.
/// Procent jest widoczny wyłącznie dla oferty udostępnionej przez sklep.
class CampaignIcon extends StatelessWidget {
  const CampaignIcon({
    super.key,
    required this.icon,
    required this.color,
    this.discountPercent,
  });

  final IconData icon;
  final Color color;
  final int? discountPercent;

  @override
  Widget build(BuildContext context) {
    final discount = discountPercent;
    return Semantics(
      label: discount == null ? 'Pakiet' : 'Rabat $discount procent',
      child: SizedBox(
        width: 82,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 7,
              top: 9,
              child: Icon(icon, color: color, size: 31),
            ),
            if (discount != null)
              Positioned(
                right: -3,
                top: 3,
                child: Transform.rotate(
                  angle: -math.pi / 9,
                  child: Container(
                    width: 70,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9F1749),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'RABAT -$discount%',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
