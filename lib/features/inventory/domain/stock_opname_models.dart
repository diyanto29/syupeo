class StockOpnameSession {
  const StockOpnameSession({
    required this.id,
    required this.businessId,
    required this.outletId,
    required this.sessionNumber,
    required this.status,
    required this.opnameType,
    this.notes,
    this.totalSystemValue = 0,
    this.totalPhysicalValue = 0,
    this.totalDiscrepancyValue = 0,
    this.startedAt,
    this.completedAt,
    this.conductedBy,
    this.items = const [],
  });

  final String id;
  final String businessId;
  final String outletId;
  final String sessionNumber;
  final String status; // 'draft', 'in_progress', 'completed', 'cancelled'
  final String opnameType; // 'daily_closing', 'weekly', 'full_monthly'
  final String? notes;
  final double totalSystemValue;
  final double totalPhysicalValue;
  final double totalDiscrepancyValue;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? conductedBy;
  final List<StockOpnameItem> items;

  bool get isCompleted => status == 'completed';
  bool get isDraft => status == 'draft' || status == 'in_progress';

  factory StockOpnameSession.fromJson(Map<String, dynamic> json) {
    return StockOpnameSession(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      outletId: json['outlet_id'] as String,
      sessionNumber: (json['session_number'] as String?) ?? 'OP-000',
      status: (json['status'] as String?) ?? 'draft',
      opnameType: (json['opname_type'] as String?) ?? 'daily_closing',
      notes: json['notes'] as String?,
      totalSystemValue: (json['total_system_value'] as num?)?.toDouble() ?? 0.0,
      totalPhysicalValue: (json['total_physical_value'] as num?)?.toDouble() ?? 0.0,
      totalDiscrepancyValue: (json['total_discrepancy_value'] as num?)?.toDouble() ?? 0.0,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
      conductedBy: json['conducted_by'] as String?,
      items: json['stock_opname_items'] != null
          ? (json['stock_opname_items'] as List<dynamic>)
              .map((e) => StockOpnameItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'outlet_id': outletId,
      'session_number': sessionNumber,
      'status': status,
      'opname_type': opnameType,
      'notes': notes,
      'total_system_value': totalSystemValue,
      'total_physical_value': totalPhysicalValue,
      'total_discrepancy_value': totalDiscrepancyValue,
      'started_at': startedAt?.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'conducted_by': conductedBy,
    };
  }

  StockOpnameSession copyWith({
    String? status,
    String? notes,
    double? totalSystemValue,
    double? totalPhysicalValue,
    double? totalDiscrepancyValue,
    DateTime? completedAt,
    List<StockOpnameItem>? items,
  }) {
    return StockOpnameSession(
      id: id,
      businessId: businessId,
      outletId: outletId,
      sessionNumber: sessionNumber,
      status: status ?? this.status,
      opnameType: opnameType,
      notes: notes ?? this.notes,
      totalSystemValue: totalSystemValue ?? this.totalSystemValue,
      totalPhysicalValue: totalPhysicalValue ?? this.totalPhysicalValue,
      totalDiscrepancyValue: totalDiscrepancyValue ?? this.totalDiscrepancyValue,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      conductedBy: conductedBy,
      items: items ?? this.items,
    );
  }
}

class StockOpnameItem {
  const StockOpnameItem({
    required this.id,
    required this.sessionId,
    this.ingredientId,
    this.menuItemId,
    required this.itemName,
    this.storageLocation = 'General',
    required this.unit,
    required this.systemStock,
    required this.physicalStock,
    this.discrepancyQuantity = 0,
    required this.unitCost,
    this.discrepancyValue = 0,
    this.discrepancyReason,
    this.notes,
    this.countedAt,
  });

  final String id;
  final String sessionId;
  final String? ingredientId;
  final String? menuItemId;
  final String itemName;
  final String storageLocation;
  final String unit;
  final double systemStock;
  final double physicalStock;
  final double discrepancyQuantity;
  final double unitCost;
  final double discrepancyValue;
  final String? discrepancyReason;
  final String? notes;
  final DateTime? countedAt;

  bool get hasDiscrepancy => (physicalStock - systemStock).abs() > 0.0001;
  double get calculatedDiff => physicalStock - systemStock;
  double get calculatedLossOrGain => calculatedDiff * unitCost;

  factory StockOpnameItem.fromJson(Map<String, dynamic> json) {
    final sys = (json['system_stock'] as num?)?.toDouble() ?? 0.0;
    final phys = (json['physical_stock'] as num?)?.toDouble() ?? 0.0;
    final cost = (json['unit_cost'] as num?)?.toDouble() ?? 0.0;
    final diff = (json['discrepancy_quantity'] as num?)?.toDouble() ?? (phys - sys);
    final val = (json['discrepancy_value'] as num?)?.toDouble() ?? (diff * cost);

    return StockOpnameItem(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      ingredientId: json['ingredient_id'] as String?,
      menuItemId: json['menu_item_id'] as String?,
      itemName: (json['item_name'] as String?) ?? '',
      storageLocation: (json['storage_location'] as String?) ?? 'General',
      unit: (json['unit'] as String?) ?? 'pcs',
      systemStock: sys,
      physicalStock: phys,
      discrepancyQuantity: diff,
      unitCost: cost,
      discrepancyValue: val,
      discrepancyReason: json['discrepancy_reason'] as String?,
      notes: json['notes'] as String?,
      countedAt: json['counted_at'] != null ? DateTime.tryParse(json['counted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'ingredient_id': ingredientId,
      'menu_item_id': menuItemId,
      'item_name': itemName,
      'storage_location': storageLocation,
      'unit': unit,
      'system_stock': systemStock,
      'physical_stock': physicalStock,
      'unit_cost': unitCost,
      'discrepancy_reason': discrepancyReason,
      'notes': notes,
    };
  }

  StockOpnameItem copyWith({
    double? physicalStock,
    String? discrepancyReason,
    String? notes,
  }) {
    final newPhysical = physicalStock ?? this.physicalStock;
    final newDiff = newPhysical - systemStock;
    final newVal = newDiff * unitCost;

    return StockOpnameItem(
      id: id,
      sessionId: sessionId,
      ingredientId: ingredientId,
      menuItemId: menuItemId,
      itemName: itemName,
      storageLocation: storageLocation,
      unit: unit,
      systemStock: systemStock,
      physicalStock: newPhysical,
      discrepancyQuantity: newDiff,
      unitCost: unitCost,
      discrepancyValue: newVal,
      discrepancyReason: discrepancyReason ?? this.discrepancyReason,
      notes: notes ?? this.notes,
      countedAt: DateTime.now(),
    );
  }
}
