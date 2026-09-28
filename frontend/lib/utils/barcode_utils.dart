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
  const supportedLengths = {8, 12, 13, 14};
  if (!supportedLengths.contains(digits.length)) return null;
  return hasValidGtinChecksum(digits) ? digits : null;
}

bool hasValidGtinChecksum(String code) {
  if (!RegExp(r'^\d+$').hasMatch(code) || code.length < 2) return false;
  var sum = 0;
  for (var index = code.length - 2; index >= 0; index--) {
    final digit = int.parse(code[index]);
    final distanceFromCheckDigit = code.length - 1 - index;
    sum += digit * (distanceFromCheckDigit.isOdd ? 3 : 1);
  }
  final expected = (10 - (sum % 10)) % 10;
  return expected == int.parse(code[code.length - 1]);
}

class BarcodeScanConfirmation {
  BarcodeScanConfirmation({this.maxInterval = const Duration(seconds: 1)});

  final Duration maxInterval;
  String? _candidate;
  DateTime? _detectedAt;

  bool confirm(String code, DateTime now) {
    final repeated =
        _candidate == code &&
        _detectedAt != null &&
        now.difference(_detectedAt!) <= maxInterval;
    if (repeated) {
      reset();
      return true;
    }
    _candidate = code;
    _detectedAt = now;
    return false;
  }

  void reset() {
    _candidate = null;
    _detectedAt = null;
  }
}
