class ProTierOption {
  final String code;
  final String label;
  final int months;
  final bool isLifetime;
  final double price;
  final double? originalPrice;
  final bool isActive;
  final String? badge;
  final String subtitle;

  const ProTierOption({
    required this.code,
    required this.label,
    required this.months,
    this.isLifetime = false,
    required this.price,
    this.originalPrice,
    this.isActive = true,
    this.badge,
    required this.subtitle,
  });

  bool get hasDiscount => originalPrice != null && originalPrice! > price;

  int? get discountPercentage {
    if (!hasDiscount) return null;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }

  factory ProTierOption.fromMap(Map<String, dynamic> map) {
    final code = map['code'] as String? ?? 'custom';
    final name = map['name'] as String? ?? (map['label'] as String? ?? 'Paket Pro');
    final months = (map['months'] as num?)?.toInt() ?? 1;
    final isLifetime = map['is_lifetime'] == true || code == 'lifetime';
    final price = (map['price'] as num?)?.toDouble() ?? 0.0;
    final originalPrice = (map['original_price'] as num?)?.toDouble() ??
        (map['strike_through_price'] as num?)?.toDouble();
    final isActive = map['is_active'] != false;
    final badge = map['badge'] as String?;
    final subtitle = map['subtitle'] as String? ??
        (isLifetime ? 'sekali bayar selamanya' : '/$name');

    return ProTierOption(
      code: code,
      label: name,
      months: months,
      isLifetime: isLifetime,
      price: price,
      originalPrice: originalPrice,
      isActive: isActive,
      badge: badge,
      subtitle: subtitle,
    );
  }
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.code,
    required this.maxTransactionsMonth,
    required this.maxProducts,
    required this.maxOutlets,
    required this.features,
    required this.priceMonthly,
    this.pricingTiers = const {},
  });

  final String id;
  final String name;
  final String code;
  final int maxTransactionsMonth;
  final int maxProducts;
  final int maxOutlets;
  final Map<String, dynamic> features;
  final double priceMonthly;
  final Map<String, dynamic> pricingTiers;

  factory SubscriptionPlan.fromMap(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Paket',
      code: json['code'] as String? ?? 'free',
      maxTransactionsMonth:
          (json['max_transactions_month'] as num?)?.toInt() ?? 1000,
      maxProducts: (json['max_products'] as num?)?.toInt() ?? 1000,
      maxOutlets: (json['max_outlets'] as num?)?.toInt() ?? 10,
      features: json['features'] as Map<String, dynamic>? ?? {},
      priceMonthly: (json['price_monthly'] as num?)?.toDouble() ?? 0.0,
      pricingTiers: json['pricing_tiers'] as Map<String, dynamic>? ?? {},
    );
  }

  double getTierPrice(String tierCode, double defaultPrice) {
    final val = pricingTiers[tierCode];
    if (val is num) return val.toDouble();
    return defaultPrice;
  }

  bool isFeatureEnabled(String featureKey) {
    if (features[featureKey] == true) return true;
    // Map common aliases between template keys and subscription plan keys
    if (featureKey == 'kitchen_kds' || featureKey == 'kds') {
      return features['kds'] == true || features['kitchen_kds'] == true;
    }
    if (featureKey == 'qr_order' || featureKey == 'qr_ordering') {
      return features['qr_ordering'] == true || features['qr_order'] == true;
    }
    if (featureKey == 'table_mgmt' || featureKey == 'table_management') {
      return features['table_management'] == true || features['table_mgmt'] == true;
    }
    if (featureKey == 'inventory' || featureKey == 'inventory_management') {
      return features['inventory_management'] == true || features['inventory'] == true;
    }
    if (featureKey == 'reports' || featureKey == 'advanced_reports') {
      return features['advanced_reports'] == true || features['reports'] == true;
    }
    return false;
  }

  /// Mengambil daftar paket durasi Pro yang aktif (tidak di-hide oleh admin).
  List<ProTierOption> getActiveProTiers() {
    final rawTiers = pricingTiers['tiers'];
    if (rawTiers is List && rawTiers.isNotEmpty) {
      return rawTiers
          .whereType<Map>()
          .map((m) => ProTierOption.fromMap(Map<String, dynamic>.from(m)))
          .where((t) => t.isActive)
          .toList();
    }

    // Fallback backward-compatibility untuk format lama
    final visibility = pricingTiers['visibility'] as Map<String, dynamic>?;
    final isLifetimeActive =
        visibility?['lifetime'] ?? (pricingTiers['lifetime_active'] ?? true);
    final is1MonthActive = visibility?['1_month'] ?? true;
    final is3MonthsActive = visibility?['3_months'] ?? true;
    final is6MonthsActive = visibility?['6_months'] ?? true;
    final is12MonthsActive = visibility?['12_months'] ?? true;

    final price1Month =
        getTierPrice('1_month', priceMonthly > 0 ? priceMonthly : 49000);
    final price3Months = getTierPrice('3_months', 129000);
    final price6Months = getTierPrice('6_months', 239000);
    final price1Year = getTierPrice('12_months', 399000);
    final priceLifetime = getTierPrice('lifetime', 799000);

    String? calcBadge(double price, int months) {
      if (price1Month <= 0 || months <= 0) return null;
      final standard = price1Month * months;
      final discount = (((standard - price) / standard) * 100).round();
      return discount > 0 ? 'HEMAT $discount%' : null;
    }

    double? calcOriginal(double price, int months) {
      if (price1Month <= 0 || months <= 0) return null;
      final standard = price1Month * months;
      return standard > price ? standard : null;
    }

    final list = <ProTierOption>[];
    if (is1MonthActive) {
      list.add(
        ProTierOption(
          code: '1_month',
          label: '1 Bulan',
          months: 1,
          price: price1Month,
          subtitle: '/bulan',
        ),
      );
    }
    if (is3MonthsActive) {
      list.add(
        ProTierOption(
          code: '3_months',
          label: '3 Bulan',
          months: 3,
          price: price3Months,
          originalPrice: calcOriginal(price3Months, 3),
          subtitle: '/3 bulan',
          badge: calcBadge(price3Months, 3),
        ),
      );
    }
    if (is6MonthsActive) {
      list.add(
        ProTierOption(
          code: '6_months',
          label: '6 Bulan',
          months: 6,
          price: price6Months,
          originalPrice: calcOriginal(price6Months, 6),
          subtitle: '/6 bulan',
          badge: calcBadge(price6Months, 6),
        ),
      );
    }
    if (is12MonthsActive) {
      list.add(
        ProTierOption(
          code: '12_months',
          label: '1 Tahun',
          months: 12,
          price: price1Year,
          originalPrice: calcOriginal(price1Year, 12),
          subtitle: '/tahun',
          badge: calcBadge(price1Year, 12),
        ),
      );
    }
    if (isLifetimeActive) {
      list.add(
        ProTierOption(
          code: 'lifetime',
          label: 'Lifetime',
          months: 0,
          isLifetime: true,
          price: priceLifetime,
          originalPrice: priceLifetime < 999000 ? 999000 : null,
          subtitle: 'sekali bayar selamanya',
          badge: 'BEST VALUE 👑',
        ),
      );
    }
    return list;
  }
}
