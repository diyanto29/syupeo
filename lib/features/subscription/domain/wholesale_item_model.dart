class WholesaleItem {
  final String id;
  final String name;
  final String? barcode;
  final String category;
  final String? brand;
  final int wholesalePrice;
  final int suggestedRetailPrice;
  final String unit;
  final String? wholesaleUnit;
  final int? conversionRatio;
  final int? wholesaleBasePrice;
  final int? wholesaleSellingPrice;
  final String icon;

  const WholesaleItem({
    required this.id,
    required this.name,
    this.barcode,
    required this.category,
    this.brand,
    required this.wholesalePrice,
    required this.suggestedRetailPrice,
    required this.unit,
    this.wholesaleUnit,
    this.conversionRatio,
    this.wholesaleBasePrice,
    this.wholesaleSellingPrice,
    this.icon = '📦',
  });

  factory WholesaleItem.fromMap(Map<String, dynamic> map) {
    final rawCategory = (map['category'] as String?)?.trim() ?? 'Umum';
    final cat = rawCategory.isEmpty ? 'Umum' : rawCategory;

    final base = (map['base_price'] as num? ?? 0).toInt();
    final selling = (map['selling_price'] as num? ?? 0).toInt();
    final unitStr = (map['unit'] as String?)?.trim();

    return WholesaleItem(
      id: map['id']?.toString() ?? '',
      name: (map['name'] as String?)?.trim() ?? 'Produk Kulakan',
      barcode: map['barcode'] as String?,
      category: cat,
      brand: map['brand'] as String?,
      wholesalePrice: base,
      suggestedRetailPrice: selling > 0 ? selling : (base * 1.2).toInt(),
      unit: (unitStr != null && unitStr.isNotEmpty) ? unitStr : 'Pcs',
      wholesaleUnit: map['wholesale_unit'] as String?,
      conversionRatio: (map['conversion_ratio'] as num?)?.toInt(),
      wholesaleBasePrice: (map['wholesale_base_price'] as num?)?.toInt(),
      wholesaleSellingPrice: (map['wholesale_selling_price'] as num?)?.toInt(),
      icon: _resolveCategoryIcon(cat, map['name'] as String?),
    );
  }

  int get profit => suggestedRetailPrice - wholesalePrice;
  double get marginPercentage =>
      suggestedRetailPrice > 0 ? (profit / suggestedRetailPrice) * 100 : 0;

  static String _resolveCategoryIcon(String category, String? name) {
    final c = category.toLowerCase();
    final n = (name ?? '').toLowerCase();

    if (c.contains('sembako') || n.contains('beras') || n.contains('minyak') || n.contains('gula') || n.contains('terigu')) {
      return '🌾';
    }
    if (c.contains('makanan') || c.contains('snack') || n.contains('mie') || n.contains('indomie') || n.contains('biskuit')) {
      return '🍜';
    }
    if (c.contains('minuman') || c.contains('mineral') || n.contains('kopi') || n.contains('teh') || n.contains('vica') || n.contains('cleo') || n.contains('air')) {
      return '☕';
    }
    if (c.contains('rumah') || c.contains('deterjen') || n.contains('sabun') || n.contains('shampoo') || n.contains('rinso') || n.contains('sunlight')) {
      return '🧼';
    }
    if (c.contains('aksesori') || c.contains('fashion') || n.contains('case') || n.contains('charm') || n.contains('gelang')) {
      return '✨';
    }
    if (c.contains('beauty') || c.contains('perawatan') || c.contains('kosmetik') || n.contains('makarizo') || n.contains('serum') || n.contains('creambath')) {
      return '💄';
    }
    if (c.contains('rokok')) {
      return '🚬';
    }
    return '📦';
  }
}

