import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProductContributionRewardBanner extends StatelessWidget {
  final bool compact;

  const ProductContributionRewardBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE3A008);
    return Semantics(
      label:
          'Nagroda: jeden punkt Premium za dodanie nowego, unikalnego produktu do bazy.',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withOpacity(0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 32 : 36,
              height: compact ? 32 : 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.stars_rounded,
                size: compact ? 18 : 20,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zyskaj 1 punkt Premium',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Zeskanuj kod lub dodaj ręcznie nowy, unikalny produkt do bazy.',
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      height: 1.3,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8, top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '+1 pkt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
