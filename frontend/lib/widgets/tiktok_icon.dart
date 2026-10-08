import 'package:flutter/material.dart';

/// Mała, czytelna ikona TikToka bez dokładania ciężkiej biblioteki ikon.
/// Kolorowe przesunięcia pozostają rozpoznawalne także w trybie ciemnym.
class TikTokIcon extends StatelessWidget {
  final double size;

  const TikTokIcon({super.key, this.size = 15});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TikTokIconPainter(
          foregroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF161823),
        ),
      ),
    );
  }
}

class _TikTokIconPainter extends CustomPainter {
  static const _cyan = Color(0xFF25F4EE);
  static const _pink = Color(0xFFFE2C55);
  final Color foregroundColor;

  const _TikTokIconPainter({required this.foregroundColor});

  Path _note(Size size, Offset offset) {
    final scale = size.shortestSide / 16;
    return Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(5.2 * scale, 12 * scale) + offset,
          radius: 3.1 * scale,
        ),
      )
      ..addRect(
        Rect.fromLTWH(
          7.3 * scale + offset.dx,
          2.1 * scale + offset.dy,
          2.6 * scale,
          10 * scale,
        ),
      )
      ..moveTo(8.7 * scale + offset.dx, 2.1 * scale + offset.dy)
      ..cubicTo(
        10.2 * scale + offset.dx,
        5.1 * scale + offset.dy,
        12.1 * scale + offset.dx,
        6 * scale + offset.dy,
        14.4 * scale + offset.dx,
        6 * scale + offset.dy,
      )
      ..lineTo(14.4 * scale + offset.dx, 8.6 * scale + offset.dy)
      ..cubicTo(
        11.9 * scale + offset.dx,
        8.6 * scale + offset.dy,
        9.9 * scale + offset.dx,
        7.7 * scale + offset.dy,
        8.7 * scale + offset.dx,
        6.7 * scale + offset.dy,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 16;
    canvas.drawPath(
      _note(size, Offset(-0.75 * scale, 0.45 * scale)),
      Paint()..color = _cyan,
    );
    canvas.drawPath(
      _note(size, Offset(0.75 * scale, 0.1 * scale)),
      Paint()..color = _pink,
    );
    canvas.drawPath(_note(size, Offset.zero), Paint()..color = foregroundColor);
  }

  @override
  bool shouldRepaint(covariant _TikTokIconPainter oldDelegate) =>
      foregroundColor != oldDelegate.foregroundColor;
}
