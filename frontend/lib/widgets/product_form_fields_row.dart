import 'package:flutter/material.dart';

/// Keeps the existing two-column form at ordinary sizes. Larger text/narrow
/// sheets get full-width controls instead of clipped units or smaller type.
class ProductFormFieldsRow extends StatelessWidget {
  final Widget first;
  final Widget second;
  final int firstFlex;
  final double? secondWidth;

  const ProductFormFieldsRow({
    super.key,
    required this.first,
    required this.second,
    this.firstFlex = 1,
    this.secondWidth,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(16) > 20.8;
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 10), second],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: firstFlex, child: first),
          const SizedBox(width: 10),
          if (secondWidth != null)
            SizedBox(width: secondWidth, child: second)
          else
            Expanded(child: second),
        ],
      );
    },
  );
}
