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
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id']?.toString() ?? '',
      productName: json['product_name'] as String? ?? '',
      storeName: json['store_name'] as String? ?? '',
      regularPrice: (json['regular_price'] as num?)?.toDouble() ?? 0.0,
      promoPrice: (json['promo_price'] as num?)?.toDouble() ?? 0.0,
      promoType: json['promo_type'] as String? ?? 'price_cut',
      promoDescription: json['promo_description'] as String?,
      validFrom: DateTime.parse(json['valid_from'] as String),
      validUntil: DateTime.parse(json['valid_until'] as String),
      requiresLoyaltyCard: json['requires_loyalty_card'] as bool? ?? false,
      savings: (json['savings'] as num?)?.toDouble() ?? 0.0,
      savingsPercent: json['savings_percent'] as int? ?? 0,
    );
  }
}
