/// Normalizuje tekst zwrócony przez aparat do samego numeru GTIN.
///
/// Skanery mogą poprzedzać wartość trzyznakowym identyfikatorem AIM,
/// np. `]E0` dla EAN/UPC. Cyfra z tego prefiksu nie jest częścią kodu.
String? normalizeScannedBarcode(String? value) {
  if (value == null) return null;
  final withoutAimPrefix = value.trim().replaceFirst(
        RegExp(r'^\][A-Za-z][0-9]'),
        '',
      );
  final digits = withoutAimPrefix.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length >= 8 && digits.length <= 14 ? digits : null;
}
