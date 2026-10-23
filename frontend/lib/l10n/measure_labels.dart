import 'app_localizations.dart';

/// Presentation only: persisted Polish measure identifiers never change.
/// In particular, szklanka remains its explicit product-specific ml/g amount;
/// translating it as glass does not introduce an imperial cup conversion.
extension MeasureLabels on AppLocalizations {
  String measureName(String code, {String? fallback}) {
    if (!localeName.startsWith('en') && fallback != null) return fallback;
    return switch (code) {
      'opak' => measurePack,
      'porcja' => measureServing,
      'szt' => measurePiece,
      'lyzeczka' => measureTeaspoon,
      'szklanka' => measureGlass,
      'g' => measureGrams,
      'ml' => measureMillilitres,
      _ => fallback ?? code,
    };
  }

  String measureQuantityLabel(
    String code, {
    required String fallback,
    num? amount,
  }) {
    if (!localeName.startsWith('en')) return fallback;
    if (code == 'g' || code == 'ml') return code;
    final name = measureName(code, fallback: fallback);
    if (amount == 1) return name;
    return switch (code) {
      'szklanka' => '${name}es',
      'opak' || 'porcja' || 'szt' || 'lyzeczka' => '${name}s',
      _ => name,
    };
  }
}
