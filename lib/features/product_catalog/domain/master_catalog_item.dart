class MasterCatalogItem {
  const MasterCatalogItem({
    required this.id,
    required this.name,
    this.barcode,
    this.category,
    this.brand,
    this.basePrice = 0,
    this.sellingPrice = 0,
    this.unit,
  });

  final String id;
  final String name;
  final String? barcode;
  final String? category;
  final String? brand;
  final double basePrice;
  final double sellingPrice;
  final String? unit;

  String get subtitle {
    final parts = [
      if (brand != null && brand!.trim().isNotEmpty) brand!.trim(),
      if (category != null && category!.trim().isNotEmpty) category!.trim(),
      if (unit != null && unit!.trim().isNotEmpty) unit!.trim(),
    ];
    return parts.join(' • ');
  }

  factory MasterCatalogItem.fromJson(Map<String, dynamic> json) {
    return MasterCatalogItem(
      id: json['id'] as String,
      name: json['name'] as String,
      barcode: json['barcode'] as String?,
      category: json['category'] as String?,
      brand: json['brand'] as String?,
      basePrice: (json['base_price'] as num? ?? 0).toDouble(),
      sellingPrice: (json['selling_price'] as num? ?? 0).toDouble(),
      unit: json['unit'] as String?,
    );
  }
}
