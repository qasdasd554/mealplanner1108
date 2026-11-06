import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's original overlapping circles, painted without animation.
class DecorativeCircles extends StatelessWidget {
  const DecorativeCircles({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CirclePainter(dark),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter(this.dark);

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final scale = (size.width / 390).clamp(0.72, 1.3).toDouble();
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..drawCircle(
        Offset(size.width - 46 * scale, 36 * scale),
        136 * scale,
        paint
          ..color = AppTheme.secondaryColor.withValues(alpha: dark ? .19 : .14),
      )
      ..drawCircle(
        Offset(-12 * scale, size.height - 44 * scale),
        127 * scale,
        paint
          ..color = AppTheme.primaryColor.withValues(alpha: dark ? .15 : .12),
      )
      ..drawCircle(
        Offset(3 * scale, size.height * .40),
        58 * scale,
        paint..color = AppTheme.accentColor.withValues(alpha: dark ? .10 : .12),
      )
      ..drawCircle(
        Offset(size.width - 12 * scale, size.height * .73),
        74 * scale,
        paint
          ..color = AppTheme.secondaryColor.withValues(alpha: dark ? .12 : .09),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) => oldDelegate.dark != dark;
}
