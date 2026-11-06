import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Delikatne obramowanie sekcji Premium.
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        border: Border.all(
          color: AppTheme.premiumInk(context).withValues(alpha: 0.42),
          width: borderWidth,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child,
    );
  }
}
