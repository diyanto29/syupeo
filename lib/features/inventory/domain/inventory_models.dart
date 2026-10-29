class Supplier {
  const Supplier({
    required this.id,
    required this.businessId,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime? createdAt;

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as String,
      businessId: map['business_id'] as String,
      name: map['name'] as String,
      contactName: map['contact_name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'contact_name': contactName,
      'phone': phone,
      'email': email,
      'address': address,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Supplier copyWith({
    String? id,
    String? businessId,
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    DateTime? createdAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum PurchaseOrderStatus { draft, pending, received, cancelled }

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.businessId,
    required this.outletId,
    this.supplierId,
    required this.poNumber,
    this.status = PurchaseOrderStatus.draft,
    this.totalAmount = 0,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.receivedAt,
    this.items = const [],
    this.supplier,
  });

  final String id;
  final String businessId;
  final String outletId;
  final String? supplierId;
  final String poNumber;
  final PurchaseOrderStatus status;
  final double totalAmount;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? receivedAt;
  final List<PurchaseOrderItem> items;
  final Supplier? supplier;

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) => PurchaseOrder.fromMap(json);
  Map<String, dynamic> toJson() => {
    ...toMap(),
    'items': items.map((i) => i.toMap()).toList(),
  };

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'] as String,
      businessId: map['business_id'] as String,
      outletId: map['outlet_id'] as String,
      supplierId: map['supplier_id'] as String?,
      poNumber: map['po_number'] as String,
      status: PurchaseOrderStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'draft'),
        orElse: () => PurchaseOrderStatus.draft,
      ),
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      receivedAt: map['received_at'] != null
          ? DateTime.parse(map['received_at'] as String)
          : null,
      items: (map['items'] as List?)
              ?.map((i) => PurchaseOrderItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      supplier: map['supplier'] != null
          ? Supplier.fromMap(map['supplier'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'outlet_id': outletId,
      'supplier_id': supplierId,
      'po_number': poNumber,
      'status': status.name,
      'total_amount': totalAmount,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'received_at': receivedAt?.toIso8601String(),
    };
  }

  PurchaseOrder copyWith({
    String? id,
    String? businessId,
    String? outletId,
    String? supplierId,
    String? poNumber,
    PurchaseOrderStatus? status,
    double? totalAmount,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? receivedAt,
    List<PurchaseOrderItem>? items,
    Supplier? supplier,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      outletId: outletId ?? this.outletId,
      supplierId: supplierId ?? this.supplierId,
      poNumber: poNumber ?? this.poNumber,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      receivedAt: receivedAt ?? this.receivedAt,
      items: items ?? this.items,
      supplier: supplier ?? this.supplier,
    );
  }
}

class PurchaseOrderItem {
  const PurchaseOrderItem({
    required this.id,
    required this.poId,
    required this.menuItemId,
    required this.quantity,
    this.receivedQuantity = 0,
    this.costPrice = 0,
    this.itemName,
    this.itemUnit,
  });

  final String id;
  final String poId;
  final String menuItemId;
  final int quantity;
  final int receivedQuantity;
  final double costPrice;
  final String? itemName;
  final String? itemUnit;

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) => PurchaseOrderItem.fromMap(json);
  Map<String, dynamic> toJson() => toMap();

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      id: map['id'] as String,
      poId: map['po_id'] as String,
      menuItemId: map['menu_item_id'] as String,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      receivedQuantity: (map['received_quantity'] as num?)?.toInt() ?? 0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      itemName: map['item_name'] as String?,
      itemUnit: map['item_unit'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'po_id': poId,
      'menu_item_id': menuItemId,
      'quantity': quantity,
      'received_quantity': receivedQuantity,
      'cost_price': costPrice,
      'item_name': itemName,
      'item_unit': itemUnit,
    };
  }

  PurchaseOrderItem copyWith({
    String? id,
    String? poId,
    String? menuItemId,
    int? quantity,
    int? receivedQuantity,
    double? costPrice,
    String? itemName,
    String? itemUnit,
  }) {
    return PurchaseOrderItem(
      id: id ?? this.id,
      poId: poId ?? this.poId,
      menuItemId: menuItemId ?? this.menuItemId,
      quantity: quantity ?? this.quantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      costPrice: costPrice ?? this.costPrice,
      itemName: itemName ?? this.itemName,
      itemUnit: itemUnit ?? this.itemUnit,
    );
  }
}
