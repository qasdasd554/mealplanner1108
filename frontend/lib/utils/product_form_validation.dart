/// Client-side mirror of ProductSubmission / ProductLabelConfirmation bounds.
/// Empty optional fields stay absent; never coerce invalid input into zero.
double? parseProductFormNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

/// Editable source data is not a display-only rounded total. Preserve its
/// precision so 0.04 does not become a confirmed zero on the next save.
String formatProductFormNumber(double? value) {
  if (value == null || !value.isFinite || value < 0) return '';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

bool validProductFormNumber(
  String text, {
  required double maximum,
  bool allowZero = true,
  bool required = false,
}) {
  if (text.trim().isEmpty) return !required;
  final value = parseProductFormNumber(text);
  return value != null &&
      value.isFinite &&
      (allowZero ? value >= 0 : value > 0) &&
      value <= maximum;
}
