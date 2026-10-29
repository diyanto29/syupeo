class Ingredient {
  const Ingredient({
    required this.id,
    required this.businessId,
    this.outletId,
    this.sku,
    required this.name,
    this.category,
    this.baseUnit = 'gram',
    this.purchaseUnit = 'kg',
    this.conversionRatio = 1000.0,
    this.currentStock = 0.0,
    this.minStockAlert = 0.0,
    this.costPerBaseUnit = 0.0,
    this.storageType = 'dry',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String? outletId;
  final String? sku;
  final String name;
  final String? category;
  final String baseUnit;
  final String purchaseUnit;
  final double conversionRatio;
  final double currentStock;
  final double minStockAlert;
  final double costPerBaseUnit;
  final String storageType;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get costPerPurchaseUnit => costPerBaseUnit * conversionRatio;
  bool get isLowStock => currentStock <= minStockAlert;
  bool get isOutOfStock => currentStock <= 0;

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      outletId: json['outlet_id'] as String?,
      sku: json['sku'] as String?,
      name: json['name'] as String,
      category: json['category'] as String?,
      baseUnit: (json['base_unit'] as String?) ?? 'gram',
      purchaseUnit: (json['purchase_unit'] as String?) ?? 'kg',
      conversionRatio: (json['conversion_ratio'] as num?)?.toDouble() ?? 1000.0,
      currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0.0,
      minStockAlert: (json['min_stock_alert'] as num?)?.toDouble() ?? 0.0,
      costPerBaseUnit: (json['cost_per_base_unit'] as num?)?.toDouble() ?? 0.0,
      storageType: (json['storage_type'] as String?) ?? 'dry',
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'outlet_id': outletId,
      'sku': sku,
      'name': name,
      'category': category,
      'base_unit': baseUnit,
      'purchase_unit': purchaseUnit,
      'conversion_ratio': conversionRatio,
      'current_stock': currentStock,
      'min_stock_alert': minStockAlert,
      'cost_per_base_unit': costPerBaseUnit,
      'storage_type': storageType,
      'is_active': isActive,
    };
  }

  Ingredient copyWith({
    String? id,
    String? businessId,
    String? outletId,
    String? sku,
    String? name,
    String? category,
    String? baseUnit,
    String? purchaseUnit,
    double? conversionRatio,
    double? currentStock,
    double? minStockAlert,
    double? costPerBaseUnit,
    String? storageType,
    bool? isActive,
  }) {
    return Ingredient(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      outletId: outletId ?? this.outletId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      baseUnit: baseUnit ?? this.baseUnit,
      purchaseUnit: purchaseUnit ?? this.purchaseUnit,
      conversionRatio: conversionRatio ?? this.conversionRatio,
      currentStock: currentStock ?? this.currentStock,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      costPerBaseUnit: costPerBaseUnit ?? this.costPerBaseUnit,
      storageType: storageType ?? this.storageType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class MenuItemRecipe {
  const MenuItemRecipe({
    required this.id,
    required this.businessId,
    required this.menuItemId,
    required this.ingredientId,
    required this.quantityRequired,
    required this.unit,
    this.variantId,
    this.modifierOptionId,
    this.notes,
    this.ingredient,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String menuItemId;
  final String ingredientId;
  final double quantityRequired;
  final String unit;
  final String? variantId;
  final String? modifierOptionId;
  final String? notes;
  final Ingredient? ingredient;
  final DateTime? createdAt;

  double get subtotalCost {
    if (ingredient == null) return 0.0;
    return quantityRequired * ingredient!.costPerBaseUnit;
  }

  factory MenuItemRecipe.fromJson(Map<String, dynamic> json) {
    return MenuItemRecipe(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      menuItemId: json['menu_item_id'] as String,
      ingredientId: json['ingredient_id'] as String,
      quantityRequired: (json['quantity_required'] as num?)?.toDouble() ?? 0.0,
      unit: (json['unit'] as String?) ?? 'gram',
      variantId: json['variant_id'] as String?,
      modifierOptionId: json['modifier_option_id'] as String?,
      notes: json['notes'] as String?,
      ingredient: json['inventory_ingredients'] != null
          ? Ingredient.fromJson(json['inventory_ingredients'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'menu_item_id': menuItemId,
      'ingredient_id': ingredientId,
      'quantity_required': quantityRequired,
      'unit': unit,
      'variant_id': variantId,
      'modifier_option_id': modifierOptionId,
      'notes': notes,
    };
  }

  MenuItemRecipe copyWith({
    String? id,
    String? businessId,
    String? menuItemId,
    String? ingredientId,
    double? quantityRequired,
    String? unit,
    String? variantId,
    String? modifierOptionId,
    String? notes,
    Ingredient? ingredient,
  }) {
    return MenuItemRecipe(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      menuItemId: menuItemId ?? this.menuItemId,
      ingredientId: ingredientId ?? this.ingredientId,
      quantityRequired: quantityRequired ?? this.quantityRequired,
      unit: unit ?? this.unit,
      variantId: variantId ?? this.variantId,
      modifierOptionId: modifierOptionId ?? this.modifierOptionId,
      notes: notes ?? this.notes,
      ingredient: ingredient ?? this.ingredient,
      createdAt: createdAt,
    );
  }
}

class IngredientMovement {
  const IngredientMovement({
    required this.id,
    required this.businessId,
    this.outletId,
    required this.ingredientId,
    required this.movementType,
    required this.quantityDelta,
    required this.balanceAfter,
    this.note,
    this.referenceId,
    this.performedBy,
    this.createdAt,
    this.ingredient,
  });

  final String id;
  final String businessId;
  final String? outletId;
  final String ingredientId;
  final String movementType;
  final double quantityDelta;
  final double balanceAfter;
  final String? note;
  final String? referenceId;
  final String? performedBy;
  final DateTime? createdAt;
  final Ingredient? ingredient;

  factory IngredientMovement.fromJson(Map<String, dynamic> json) {
    return IngredientMovement(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      outletId: json['outlet_id'] as String?,
      ingredientId: json['ingredient_id'] as String,
      movementType: json['movement_type'] as String,
      quantityDelta: (json['quantity_delta'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String?,
      referenceId: json['reference_id'] as String?,
      performedBy: json['performed_by'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      ingredient: json['inventory_ingredients'] != null
          ? Ingredient.fromJson(json['inventory_ingredients'] as Map<String, dynamic>)
          : null,
    );
  }
}
