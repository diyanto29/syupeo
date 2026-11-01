import 'menu_category_models.dart';

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.businessId,
    this.price = 0,
    this.unit = 'pcs',
    this.description = '',
    this.imageUrl,
    this.stockAvailable = true,
    this.trackStockQuantity = false,
    this.stockQuantity = 0,
    this.ingredients = const [],
    this.recipeCost = 0,
    this.sku,
    this.barcode,
    this.category,
    this.variants = const [],
    this.tieredPrices = const [],
    this.isPackage = false,
    this.packageItems = const [],
  });

  final String id;
  final String name;
  final String categoryId;
  final double price;
  final String businessId;
  final String unit;
  final String description;
  final String? imageUrl;
  final bool stockAvailable;
  final bool trackStockQuantity;
  final num stockQuantity;
  final List<String> ingredients;
  final double recipeCost;
  final String? sku;
  final String? barcode;
  final MenuCatalogCategory? category;
  final List<MenuItemVariant> variants;
  final List<TieredPrice> tieredPrices;
  final bool isPackage;
  final List<MenuPackageItem> packageItems;

  String get categoryName => category?.name ?? 'Tanpa kategori';

  String get packageSummary => packageItems.isEmpty
      ? ''
      : packageItems
            .map((p) => '${p.componentName ?? "Item"} (${p.quantity}x)')
            .join(', ');

  int? get categoryVisualIndex => category?.visualIndex;

  String get displayUnit {
    final trimmed = unit.trim();
    return trimmed.isEmpty ? 'pcs' : trimmed;
  }

  /// Format kuantitas stok: jika bilangan bulat tampilkan bulat (2), jika desimal tampilkan bersih (1.5 atau 0.25)
  String get formattedStock {
    if (stockQuantity % 1 == 0) {
      return '${stockQuantity.toInt()}';
    }
    return stockQuantity.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  bool get isOutOfTrackedStock => trackStockQuantity && stockQuantity <= 0;

  bool get isSellable => stockAvailable && !isOutOfTrackedStock;

  String get stockStatusLabel {
    if (!stockAvailable) {
      return 'Nonaktif';
    }
    if (trackStockQuantity) {
      return 'Stok $formattedStock $displayUnit';
    }
    return 'Tersedia';
  }

  double resolvePrice(int quantity, {double? basePrice}) {
    final tier = getApplicableTier(quantity);
    return tier?.price ?? (basePrice ?? price);
  }

  TieredPrice? getApplicableTier(int quantity) {
    if (tieredPrices.isEmpty) return null;

    final sortedTiers = [...tieredPrices]
      ..sort((a, b) => b.minQuantity.compareTo(a.minQuantity));

    for (final tier in sortedTiers) {
      if (quantity >= tier.minQuantity) {
        return tier;
      }
    }
    return null;
  }

  MenuItem copyWith({
    String? id,
    String? name,
    String? categoryId,
    double? price,
    String? businessId,
    String? unit,
    String? description,
    String? imageUrl,
    bool? stockAvailable,
    bool? trackStockQuantity,
    num? stockQuantity,
    List<String>? ingredients,
    double? recipeCost,
    String? sku,
    String? barcode,
    MenuCatalogCategory? category,
    List<MenuItemVariant>? variants,
    List<TieredPrice>? tieredPrices,
    bool? isPackage,
    List<MenuPackageItem>? packageItems,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      businessId: businessId ?? this.businessId,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      trackStockQuantity: trackStockQuantity ?? this.trackStockQuantity,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      ingredients: ingredients ?? this.ingredients,
      recipeCost: recipeCost ?? this.recipeCost,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      variants: variants ?? this.variants,
      tieredPrices: tieredPrices ?? this.tieredPrices,
      isPackage: isPackage ?? this.isPackage,
      packageItems: packageItems ?? this.packageItems,
    );
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final rawCategory =
        json['menu_category'] ?? json['menu_categories'] ?? json['category'];
    Map<String, dynamic>? categoryMap;
    if (rawCategory is Map<String, dynamic>) {
      categoryMap = rawCategory;
    } else if (rawCategory is Map) {
      categoryMap = Map<String, dynamic>.from(rawCategory);
    } else if (rawCategory is List &&
        rawCategory.isNotEmpty &&
        rawCategory.first is Map) {
      categoryMap = Map<String, dynamic>.from(rawCategory.first as Map);
    }

    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryId: json['category_id'] as String? ?? '',
      price: (json['price'] as num? ?? 0).toDouble(),
      businessId: json['business_id'] as String? ?? '',
      unit: _parseUnit(json['unit']),
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      stockAvailable: json['stock_available'] as bool? ?? true,
      trackStockQuantity: json['track_stock_quantity'] as bool? ?? false,
      stockQuantity: (json['stock_quantity'] as num? ?? 0),
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      recipeCost: (json['recipe_cost'] as num? ?? 0).toDouble(),
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      category: categoryMap != null
          ? MenuCatalogCategory.fromJson(categoryMap)
          : null,
      variants:
          (json['menu_item_variants'] as List<dynamic>?)
              ?.map((e) => MenuItemVariant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tieredPrices:
          (json['menu_item_tiered_prices'] as List<dynamic>?)
              ?.map((e) => TieredPrice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isPackage: json['is_package'] as bool? ?? false,
      packageItems:
          (json['menu_package_items'] as List<dynamic>?)
              ?.map((e) => MenuPackageItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toDatabaseJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'price': price.round(),
      'business_id': businessId,
      'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
      'description': description,
      'image_url': imageUrl,
      'stock_available': stockAvailable,
      'track_stock_quantity': trackStockQuantity,
      'stock_quantity': stockQuantity.round(),
      'recipe_cost': recipeCost.round(),
      'cost_price': recipeCost.round(),
      if (sku != null && sku!.trim().isNotEmpty) 'sku': sku!.trim(),
      if (barcode != null && barcode!.trim().isNotEmpty)
        'barcode': barcode!.trim(),
      'is_package': isPackage,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      ...toDatabaseJson(),
      'ingredients': ingredients,
      if (category != null) 'menu_category': category!.toJson(),
      'menu_item_variants': variants.map((v) => v.toJson()).toList(),
      'menu_item_tiered_prices': tieredPrices.map((t) => t.toJson()).toList(),
      'menu_package_items': packageItems.map((p) => p.toJson()).toList(),
    };
  }

  static String _parseUnit(Object? value) {
    final unit = value is String ? value.trim() : '';
    return unit.isEmpty ? 'pcs' : unit;
  }
}

class MenuItemVariant {
  const MenuItemVariant({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.businessId,
    this.sku,
    this.barcode,
    this.stockAvailable = true,
    this.unitRatio,
  });

  final String id;
  final String menuItemId;
  final String name;
  final double price;
  final String businessId;
  final String? sku;
  final String? barcode;
  final bool stockAvailable;
  final double? unitRatio;

  /// Multiplier/rasio konsumsi terhadap stok fisik induk (Opsi 1).
  /// Contoh:
  /// - Varian "1/4 kg" atau "250g" -> 0.25
  /// - Varian "1/2 kg" atau "500g" -> 0.50
  /// - Varian "3/4 kg" atau "750g" -> 0.75
  /// - Varian "Ori 1 kg" atau "1 kg" -> 1.00
  double get multiplier {
    if (unitRatio != null && unitRatio! > 0) {
      return unitRatio!;
    }
    final lower = name.toLowerCase().replaceAll(' ', '');
    if (lower.contains('1/4') ||
        lower.contains('seperempat') ||
        lower.contains('250g') ||
        lower.contains('0.25')) {
      return 0.25;
    }
    if (lower.contains('1/2') ||
        lower.contains('setengah') ||
        lower.contains('500g') ||
        lower.contains('0.5')) {
      return 0.5;
    }
    if (lower.contains('3/4') ||
        lower.contains('750g') ||
        lower.contains('0.75')) {
      return 0.75;
    }
    return 1.0;
  }

  /// Menghitung sisa kuota penjualan untuk varian ini secara dinamis dari sisa stok fisik induk.
  int calculateAvailableQuota(num parentStockQuantity) {
    if (parentStockQuantity <= 0) return 0;
    final m = multiplier;
    if (m <= 0) return 0;
    return (parentStockQuantity / m).floor();
  }

  MenuItemVariant copyWith({
    String? id,
    String? menuItemId,
    String? name,
    double? price,
    String? businessId,
    String? sku,
    String? barcode,
    bool? stockAvailable,
    double? unitRatio,
  }) {
    return MenuItemVariant(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      price: price ?? this.price,
      businessId: businessId ?? this.businessId,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      unitRatio: unitRatio ?? this.unitRatio,
    );
  }

  factory MenuItemVariant.fromJson(Map<String, dynamic> json) {
    return MenuItemVariant(
      id: (json['id'] as String?) ?? '',
      menuItemId: (json['menu_item_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      businessId: (json['business_id'] as String?) ?? '',
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      stockAvailable: json['stock_available'] as bool? ?? true,
      unitRatio: (json['unit_ratio'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toDatabaseJson() {
    return {
      'id': id,
      'menu_item_id': menuItemId,
      'name': name,
      'price': price.round(),
      'business_id': businessId,
      if (sku != null && sku!.trim().isNotEmpty) 'sku': sku!.trim(),
      if (barcode != null && barcode!.trim().isNotEmpty)
        'barcode': barcode!.trim(),
      'stock_available': stockAvailable,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      ...toDatabaseJson(),
      if (unitRatio != null) 'unit_ratio': unitRatio,
    };
  }
}

class TieredPrice {
  const TieredPrice({this.id, required this.minQuantity, required this.price});

  final String? id;
  final int minQuantity;
  final double price;

  TieredPrice copyWith({String? id, int? minQuantity, double? price}) {
    return TieredPrice(
      id: id ?? this.id,
      minQuantity: minQuantity ?? this.minQuantity,
      price: price ?? this.price,
    );
  }

  factory TieredPrice.fromJson(Map<String, dynamic> json) {
    return TieredPrice(
      id: json['id'] as String?,
      minQuantity: (json['min_quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'min_quantity': minQuantity,
      'price': price.round(),
    };
  }
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.businessId,
    required this.outletId,
    required this.menuItemId,
    required this.movementType,
    required this.quantityBefore,
    required this.quantityDelta,
    required this.quantityAfter,
    this.note,
    this.referenceType,
    this.referenceId,
    this.performedByUserId,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String outletId;
  final String menuItemId;
  final String movementType;
  final int quantityBefore;
  final int quantityDelta;
  final int quantityAfter;
  final String? note;
  final String? referenceType;
  final String? referenceId;
  final String? performedByUserId;
  final DateTime createdAt;

  bool get isAddition => quantityDelta > 0;

  String get movementLabel => switch (movementType) {
    'initial_stock' => 'Stok awal',
    'manual_addition' => 'Tambah stok',
    'manual_reduction' => 'Kurangi stok',
    'stock_opname' => 'Stock opname',
    'sale' => 'Penjualan',
    'void_restore' => 'Batal jual',
    'refund' => 'Refund',
    _ => movementType,
  };

  factory InventoryMovement.fromJson(Map<String, dynamic> json) {
    return InventoryMovement(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      outletId: json['outlet_id'] as String,
      menuItemId: json['menu_item_id'] as String,
      movementType: json['movement_type'] as String? ?? 'manual_addition',
      quantityBefore: (json['quantity_before'] as num? ?? 0).toInt(),
      quantityDelta: (json['quantity_delta'] as num? ?? 0).toInt(),
      quantityAfter: (json['quantity_after'] as num? ?? 0).toInt(),
      note: json['note'] as String?,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      performedByUserId: json['performed_by_user_id'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class MenuPackageItem {
  const MenuPackageItem({
    this.id,
    required this.packageMenuItemId,
    required this.componentMenuItemId,
    this.quantity = 1,
    this.componentName,
    this.componentPrice,
  });

  final String? id;
  final String packageMenuItemId;
  final String componentMenuItemId;
  final int quantity;
  final String? componentName;
  final double? componentPrice;

  MenuPackageItem copyWith({
    String? id,
    String? packageMenuItemId,
    String? componentMenuItemId,
    int? quantity,
    String? componentName,
    double? componentPrice,
  }) {
    return MenuPackageItem(
      id: id ?? this.id,
      packageMenuItemId: packageMenuItemId ?? this.packageMenuItemId,
      componentMenuItemId: componentMenuItemId ?? this.componentMenuItemId,
      quantity: quantity ?? this.quantity,
      componentName: componentName ?? this.componentName,
      componentPrice: componentPrice ?? this.componentPrice,
    );
  }

  factory MenuPackageItem.fromJson(Map<String, dynamic> json) {
    final component = json['component'] is Map<String, dynamic>
        ? json['component'] as Map<String, dynamic>
        : (json['component_menu_item'] is Map<String, dynamic>
              ? json['component_menu_item'] as Map<String, dynamic>
              : null);

    return MenuPackageItem(
      id: json['id'] as String?,
      packageMenuItemId: json['package_menu_item_id'] as String? ?? '',
      componentMenuItemId: json['component_menu_item_id'] as String? ?? '',
      quantity: (json['quantity'] as num? ?? 1).toInt(),
      componentName: component?['name'] as String?,
      componentPrice: (component?['price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'package_menu_item_id': packageMenuItemId,
      'component_menu_item_id': componentMenuItemId,
      'quantity': quantity,
    };
  }
}
