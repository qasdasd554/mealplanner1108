class Promotion {
  final String id;
  final String productName;
  final String storeName;
  final double regularPrice;
  final double promoPrice;
  final String promoType;
  final String? promoDescription;
  final DateTime validFrom;
  final DateTime validUntil;
  final bool requiresLoyaltyCard;
  final double savings;
  final int savingsPercent;
  final String reviewStatus;

  Promotion({
    required this.id,
    required this.productName,
    required this.storeName,
    required this.regularPrice,
    required this.promoPrice,
    required this.promoType,
    this.promoDescription,
    required this.validFrom,
    required this.validUntil,
    required this.requiresLoyaltyCard,
    required this.savings,
    required this.savingsPercent,
    this.reviewStatus = 'approved',
  });

  /// Bezpiecznie parsuje wartość liczbową niezależnie od tego, czy
  /// backend zwrócił ją jako prawdziwą liczbę JSON, czy (przez pomyłkę,
  /// jak to wcześniej bywało z polami typu Decimal) jako string.
  static double _parseDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id']?.toString() ?? '',
      productName: json['product_name'] as String? ?? '',
      storeName: json['store_name'] as String? ?? '',
      regularPrice: _parseDouble(json['regular_price']),
      promoPrice: _parseDouble(json['promo_price']),
      promoType: json['promo_type'] as String? ?? 'price_cut',
      promoDescription: json['promo_description'] as String?,
      validFrom: DateTime.parse(json['valid_from'] as String),
      validUntil: DateTime.parse(json['valid_until'] as String),
      requiresLoyaltyCard: json['requires_loyalty_card'] as bool? ?? false,
      savings: _parseDouble(json['savings']),
      savingsPercent: json['savings_percent'] as int? ?? 0,
      reviewStatus: json['review_status'] as String? ?? 'approved',
    );
  }
}
