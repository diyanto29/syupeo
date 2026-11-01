import 'package:dpos/features/discount_management/domain/discount_models.dart';
import 'package:flutter/material.dart';

/// Status siklus hidup transaksi.
enum TransactionStatus {
  draft, // Belum bayar, masih bisa edit
  confirmed, // Sudah dikonfirmasi, menunggu bayar
  paid, // Sudah lunas
  partialPaid, // Sebagian dibayar
  void_, // Dibatalkan
  refunded; // Dikembalikan

  static TransactionStatus fromDb(String? value) {
    return switch (value) {
      'draft' => TransactionStatus.draft,
      'confirmed' => TransactionStatus.confirmed,
      'paid' => TransactionStatus.paid,
      'partial_paid' => TransactionStatus.partialPaid,
      'void' => TransactionStatus.void_,
      'refunded' => TransactionStatus.refunded,
      _ => TransactionStatus.draft,
    };
  }

  String get dbValue => switch (this) {
    TransactionStatus.draft => 'draft',
    TransactionStatus.confirmed => 'confirmed',
    TransactionStatus.paid => 'paid',
    TransactionStatus.partialPaid => 'partial_paid',
    TransactionStatus.void_ => 'void',
    TransactionStatus.refunded => 'refunded',
  };

  String get label => switch (this) {
    TransactionStatus.draft => 'Draft',
    TransactionStatus.confirmed => 'Dikonfirmasi',
    TransactionStatus.paid => 'Lunas',
    TransactionStatus.partialPaid => 'Bayar Sebagian',
    TransactionStatus.void_ => 'Batal',
    TransactionStatus.refunded => 'Refund',
  };

  bool get isEditable => this == TransactionStatus.draft;
  bool get isPaid => this == TransactionStatus.paid;
  bool get isFinalized =>
      this == TransactionStatus.paid ||
      this == TransactionStatus.void_ ||
      this == TransactionStatus.refunded;
}

/// Asal pesanan.
enum OrderSource {
  pos, // Dari kasir
  qrSelfOrder, // QR Code mandiri
  waiter, // Dari waiter
  online; // Online order

  static OrderSource fromDb(String? value) {
    return switch (value) {
      'pos' => OrderSource.pos,
      'qr_self_order' => OrderSource.qrSelfOrder,
      'waiter' => OrderSource.waiter,
      'online' => OrderSource.online,
      _ => OrderSource.pos,
    };
  }

  String get dbValue => switch (this) {
    OrderSource.pos => 'pos',
    OrderSource.qrSelfOrder => 'qr_self_order',
    OrderSource.waiter => 'waiter',
    OrderSource.online => 'online',
  };

  String get label => switch (this) {
    OrderSource.pos => 'Kasir',
    OrderSource.qrSelfOrder => 'QR Mandiri',
    OrderSource.waiter => 'Waiter',
    OrderSource.online => 'Online',
  };

  IconData get icon => switch (this) {
    OrderSource.pos => Icons.point_of_sale_rounded,
    OrderSource.qrSelfOrder => Icons.qr_code_rounded,
    OrderSource.waiter => Icons.person_rounded,
    OrderSource.online => Icons.language_rounded,
  };
}

/// Tipe konsumsi pesanan (Dine In vs Take Away vs Delivery vs Ojol vs Custom).
enum DiningOption {
  dineIn, // Makan di tempat
  takeAway, // Bawa pulang / bungkus
  delivery, // Pesan antar
  goFood, // GoFood
  grabFood, // GrabFood
  shopeeFood, // ShopeeFood
  custom; // Tipe kustom lainnya

  static DiningOption fromDb(String? value) {
    return switch (value?.toLowerCase()) {
      'take_away' || 'takeaway' => DiningOption.takeAway,
      'delivery' => DiningOption.delivery,
      'gofood' || 'go_food' => DiningOption.goFood,
      'grabfood' || 'grab_food' => DiningOption.grabFood,
      'shopeefood' || 'shopee_food' => DiningOption.shopeeFood,
      'custom' => DiningOption.custom,
      _ => DiningOption.dineIn,
    };
  }

  String get dbValue => switch (this) {
    DiningOption.dineIn => 'dine_in',
    DiningOption.takeAway => 'take_away',
    DiningOption.delivery => 'delivery',
    DiningOption.goFood => 'gofood',
    DiningOption.grabFood => 'grabfood',
    DiningOption.shopeeFood => 'shopeefood',
    DiningOption.custom => 'custom',
  };

  String get label => switch (this) {
    DiningOption.dineIn => 'Dine In',
    DiningOption.takeAway => 'Take Away',
    DiningOption.delivery => 'Delivery',
    DiningOption.goFood => 'GoFood',
    DiningOption.grabFood => 'GrabFood',
    DiningOption.shopeeFood => 'ShopeeFood',
    DiningOption.custom => 'Custom',
  };

  String get fullLabel => switch (this) {
    DiningOption.dineIn => 'Makan di Tempat',
    DiningOption.takeAway => 'Bawa Pulang',
    DiningOption.delivery => 'Pesan Antar',
    DiningOption.goFood => 'GoFood (Online)',
    DiningOption.grabFood => 'GrabFood (Online)',
    DiningOption.shopeeFood => 'ShopeeFood (Online)',
    DiningOption.custom => 'Pesanan Khusus',
  };

  IconData get icon => switch (this) {
    DiningOption.dineIn => Icons.restaurant_rounded,
    DiningOption.takeAway => Icons.shopping_bag_outlined,
    DiningOption.delivery => Icons.delivery_dining_rounded,
    DiningOption.goFood => Icons.two_wheeler_rounded,
    DiningOption.grabFood => Icons.two_wheeler_rounded,
    DiningOption.shopeeFood => Icons.two_wheeler_rounded,
    DiningOption.custom => Icons.storefront_rounded,
  };
}

/// Status pemrosesan pesanan di dapur (Kitchen Display System).
enum KitchenStatus {
  pending, // Menunggu dimasak
  cooking, // Sedang dimasak oleh koki
  ready, // Masakan siap disajikan / plating selesai
  served; // Sudah diantar ke meja customer

  static KitchenStatus fromDb(String? value) {
    return switch (value?.toLowerCase()) {
      'cooking' => KitchenStatus.cooking,
      'ready' => KitchenStatus.ready,
      'served' => KitchenStatus.served,
      _ => KitchenStatus.pending,
    };
  }

  String get dbValue => name;

  String get label => switch (this) {
    KitchenStatus.pending => 'Menunggu',
    KitchenStatus.cooking => 'Sedang Dimasak',
    KitchenStatus.ready => 'Siap Saji',
    KitchenStatus.served => 'Selesai',
  };

  IconData get icon => switch (this) {
    KitchenStatus.pending => Icons.hourglass_top_rounded,
    KitchenStatus.cooking => Icons.local_fire_department_rounded,
    KitchenStatus.ready => Icons.room_service_rounded,
    KitchenStatus.served => Icons.check_circle_outline_rounded,
  };

  Color get color => switch (this) {
    KitchenStatus.pending => const Color(0xFF64748B),
    KitchenStatus.cooking => const Color(0xFFF59E0B),
    KitchenStatus.ready => const Color(0xFF10B981),
    KitchenStatus.served => const Color(0xFF3B82F6),
  };
}

/// Item di dalam cart / order.
class TransactionItem {
  const TransactionItem({
    required this.id,
    this.menuItemId,
    this.variantId,
    required this.name,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    this.notes,
    this.discountId,
    this.discountName,
    this.discountType,
    this.discountPercentage,
    this.discountAmount,
    this.discountApplied = 0,
    this.forceBasePrice = false,
    this.isPackage = false,
    this.packageComponents = const [],
    this.promoTag,
    this.isTebusMurah = false,
    this.tebusMurahPromoId,
    this.costPrice = 0,
  });

  final String id;
  final String? menuItemId;
  final String? variantId;
  final String name;
  final String? variantName;
  final int quantity;
  final double unitPrice;
  final double costPrice;
  final String? notes;

  // Package & Promo tags
  final bool isPackage;
  final List<String> packageComponents;
  final String? promoTag;
  final bool isTebusMurah;
  final String? tebusMurahPromoId;

  // Per-item discount
  final String? discountId;
  final String? discountName;
  final DiscountType? discountType;
  final double? discountPercentage;
  final double? discountAmount;
  final double discountApplied;
  final bool forceBasePrice;

  /// Subtotal sebelum diskon item.
  double get rawSubtotal => unitPrice * quantity;

  /// Subtotal setelah diskon item.
  double get subtotal =>
      (rawSubtotal - discountApplied).clamp(0, double.infinity);

  /// HPP efektif per satuan setelah mempertimbangkan fraksi varian (misal 1/2 kg, 250g, dsb)
  double get effectiveCostPrice {
    double itemCost = costPrice;
    if (variantName != null && variantName!.isNotEmpty && itemCost > 0) {
      final lower = variantName!.toLowerCase().replaceAll(' ', '');
      double mult = 1.0;
      if (lower.contains('1/4') ||
          lower.contains('seperempat') ||
          lower.contains('250g') ||
          lower.contains('0.25')) {
        mult = 0.25;
      } else if (lower.contains('1/2') ||
          lower.contains('setengah') ||
          lower.contains('500g') ||
          lower.contains('0.5')) {
        mult = 0.5;
      } else if (lower.contains('3/4') ||
          lower.contains('750g') ||
          lower.contains('0.75')) {
        mult = 0.75;
      } else if (lower.contains('1/10') ||
          lower.contains('100g') ||
          lower.contains('0.1')) {
        mult = 0.1;
      }
      if (mult < 1.0 &&
          itemCost >= unitPrice &&
          (itemCost * mult) < unitPrice) {
        itemCost = itemCost * mult;
      }
    }
    // Safeguard anti rugi palsu: jika HPP melebihi harga jual karena anomali data satuan/varian eceran
    if (unitPrice > 0 && itemCost >= unitPrice) {
      itemCost = (unitPrice * 0.85).roundToDouble();
    }
    return itemCost;
  }

  /// Total modal / HPP item.
  double get totalCost => effectiveCostPrice * quantity;

  /// Laba kotor item.
  double get itemProfit => subtotal - totalCost;

  bool get hasDiscount => discountApplied > 0;

  String get displayName {
    if (variantName != null && variantName!.isNotEmpty) {
      return '$name ($variantName)';
    }
    return name;
  }

  /// Hitung ulang discountApplied berdasarkan definisi diskon & raw subtotal.
  TransactionItem recalculateDiscount() {
    if (discountType == null) return this;
    double applied;
    if (discountType == DiscountType.percentage) {
      applied = rawSubtotal * (discountPercentage ?? 0) / 100;
    } else {
      applied = discountAmount ?? 0;
    }
    applied = applied.clamp(0, rawSubtotal);
    return copyWith(discountApplied: applied);
  }

  TransactionItem copyWith({
    String? id,
    String? menuItemId,
    String? variantId,
    String? name,
    String? variantName,
    int? quantity,
    double? unitPrice,
    double? costPrice,
    String? notes,
    String? discountId,
    bool clearDiscount = false,
    bool clearDiscountId = false,
    String? discountName,
    DiscountType? discountType,
    double? discountPercentage,
    double? discountAmount,
    double? discountApplied,
    bool? forceBasePrice,
    bool? isPackage,
    List<String>? packageComponents,
    String? promoTag,
    bool clearPromoTag = false,
    bool? isTebusMurah,
    String? tebusMurahPromoId,
  }) {
    if (clearDiscount) {
      return TransactionItem(
        id: id ?? this.id,
        menuItemId: menuItemId ?? this.menuItemId,
        variantId: variantId ?? this.variantId,
        name: name ?? this.name,
        variantName: variantName ?? this.variantName,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        costPrice: costPrice ?? this.costPrice,
        notes: notes ?? this.notes,
        forceBasePrice: forceBasePrice ?? this.forceBasePrice,
        isPackage: isPackage ?? this.isPackage,
        packageComponents: packageComponents ?? this.packageComponents,
        promoTag: clearPromoTag ? null : (promoTag ?? this.promoTag),
        isTebusMurah: isTebusMurah ?? this.isTebusMurah,
        tebusMurahPromoId: tebusMurahPromoId ?? this.tebusMurahPromoId,
      );
    }
    return TransactionItem(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      variantId: variantId ?? this.variantId,
      name: name ?? this.name,
      variantName: variantName ?? this.variantName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      notes: notes ?? this.notes,
      discountId: clearDiscountId ? null : (discountId ?? this.discountId),
      discountName: discountName ?? this.discountName,
      discountType: discountType ?? this.discountType,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      discountApplied: discountApplied ?? this.discountApplied,
      forceBasePrice: forceBasePrice ?? this.forceBasePrice,
      isPackage: isPackage ?? this.isPackage,
      packageComponents: packageComponents ?? this.packageComponents,
      promoTag: clearPromoTag ? null : (promoTag ?? this.promoTag),
      isTebusMurah: isTebusMurah ?? this.isTebusMurah,
      tebusMurahPromoId: tebusMurahPromoId ?? this.tebusMurahPromoId,
    );
  }

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    double parsedCost = 0.0;
    // Prioritaskan cost_price riil yang tersimpan di baris order_items saat transaksi terjadi
    if (json['cost_price'] != null && (json['cost_price'] as num) > 0) {
      parsedCost = (json['cost_price'] as num).toDouble();
    } else if (json['menu_items'] != null && json['menu_items'] is Map) {
      parsedCost =
          (json['menu_items']['recipe_cost'] as num?)?.toDouble() ?? 0.0;
    } else if (json['menu_item'] != null && json['menu_item'] is Map) {
      parsedCost =
          (json['menu_item']['recipe_cost'] as num?)?.toDouble() ?? 0.0;
    } else if (json['cost_price'] != null) {
      parsedCost = (json['cost_price'] as num?)?.toDouble() ?? 0.0;
    }

    return TransactionItem(
      id: json['id'] as String,
      menuItemId: json['menu_item_id'] as String?,
      variantId: json['variant_id'] as String?,
      name: json['name'] as String,
      variantName: json['variant_name'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      costPrice: parsedCost,
      notes: json['notes'] as String?,
      discountId: json['discount_id'] as String?,
      discountName: json['discount_name'] as String?,
      discountType: json['discount_type'] != null
          ? DiscountType.fromValue(json['discount_type'] as String?)
          : null,
      discountPercentage: (json['discount_percentage'] as num?)?.toDouble(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      discountApplied: (json['discount_applied'] as num?)?.toDouble() ?? 0,
      isPackage: json['is_package'] as bool? ?? false,
      packageComponents:
          (json['package_components'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      promoTag: json['promo_tag'] as String?,
      isTebusMurah: json['is_tebus_murah'] as bool? ?? false,
      tebusMurahPromoId: json['tebus_murah_promo_id'] as String?,
    );
  }

  Map<String, dynamic> toJson(String orderId) {
    return {
      'id': id,
      'order_id': orderId,
      'menu_item_id': menuItemId,
      'variant_id': variantId,
      'name': name,
      'variant_name': variantName,
      'quantity': quantity,
      'unit_price': unitPrice.roundToDouble() == unitPrice
          ? unitPrice.round()
          : unitPrice,
      'cost_price': costPrice.roundToDouble() == costPrice
          ? costPrice.round()
          : costPrice,
      'subtotal': subtotal.roundToDouble() == subtotal
          ? subtotal.round()
          : subtotal,
      'notes': notes,
    };
  }
}

/// Diskon yang diterapkan pada order.
class TransactionDiscount {
  const TransactionDiscount({
    required this.id,
    this.discountId,
    required this.name,
    required this.type,
    this.percentageValue,
    this.amountValue,
    this.maxDiscountAmount,
    required this.appliedAmount,
  });

  final String id;
  final String? discountId;
  final String name;
  final DiscountType type;
  final double? percentageValue;
  final double? amountValue;
  final double? maxDiscountAmount;
  final double appliedAmount;

  factory TransactionDiscount.fromDefinition(
    DiscountDefinition def,
    double subtotal,
  ) {
    double applied;
    if (def.type == DiscountType.percentage) {
      applied = subtotal * (def.percentageValue ?? 0) / 100;
      if (def.maxDiscountAmount != null && def.maxDiscountAmount! > 0) {
        applied = applied.clamp(0, def.maxDiscountAmount!);
      }
    } else {
      applied = def.amountValue ?? 0;
    }
    applied = applied.clamp(0, subtotal);

    return TransactionDiscount(
      id: '', // Will be set by uuid
      discountId: def.id,
      name: def.name,
      type: def.type,
      percentageValue: def.percentageValue,
      amountValue: def.amountValue,
      maxDiscountAmount: def.maxDiscountAmount,
      appliedAmount: applied,
    );
  }

  factory TransactionDiscount.fromJson(Map<String, dynamic> json) {
    return TransactionDiscount(
      id: json['id'] as String,
      discountId: json['discount_id'] as String?,
      name: json['name'] as String,
      type: DiscountType.fromValue(json['type'] as String?),
      percentageValue: (json['percentage_value'] as num?)?.toDouble(),
      amountValue: (json['amount_value'] as num?)?.toDouble(),
      maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble(),
      appliedAmount: (json['applied_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson(String orderId) {
    final validDiscountId =
        discountId != null &&
            RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(discountId!)
        ? discountId
        : null;

    return {
      'id': id,
      'order_id': orderId,
      if (validDiscountId != null) 'discount_id': validDiscountId,
      'name': name,
      'type': type.dbValue,
      if (percentageValue != null)
        'percentage_value': percentageValue!.roundToDouble() == percentageValue
            ? percentageValue!.round()
            : percentageValue,
      if (amountValue != null)
        'amount_value': amountValue!.roundToDouble() == amountValue
            ? amountValue!.round()
            : amountValue,
      if (maxDiscountAmount != null)
        'max_discount_amount':
            maxDiscountAmount!.roundToDouble() == maxDiscountAmount
            ? maxDiscountAmount!.round()
            : maxDiscountAmount,
      'applied_amount': appliedAmount.roundToDouble() == appliedAmount
          ? appliedAmount.round()
          : appliedAmount,
    };
  }
}

/// Pembayaran yang dilakukan.
class TransactionPayment {
  const TransactionPayment({
    required this.id,
    this.paymentMethodId,
    required this.methodName,
    required this.methodType,
    required this.amount,
    this.referenceNumber,
  });

  final String id;
  final String? paymentMethodId;
  final String methodName;
  final String methodType;
  final double amount;
  final String? referenceNumber;

  factory TransactionPayment.fromJson(Map<String, dynamic> json) {
    return TransactionPayment(
      id: json['id'] as String,
      paymentMethodId: json['payment_method_id'] as String?,
      methodName: json['method_name'] as String,
      methodType: json['method_type'] as String? ?? 'cash',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      referenceNumber: json['reference_number'] as String?,
    );
  }

  Map<String, dynamic> toJson(String orderId) {
    return {
      'id': id,
      'order_id': orderId,
      'payment_method': methodName.isNotEmpty ? methodName : 'Tunai',
      'payment_method_id': paymentMethodId,
      'method_name': methodName,
      'method_type': methodType,
      'amount': amount.roundToDouble() == amount ? amount.round() : amount,
      if (referenceNumber != null && referenceNumber!.isNotEmpty)
        'reference_number': referenceNumber,
    };
  }
}

/// Order / Transaksi lengkap.
class TransactionOrder {
  const TransactionOrder({
    required this.id,
    required this.outletId,
    required this.businessId,
    required this.invoiceNumber,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.tableNumber,
    required this.status,
    this.orderSource = OrderSource.pos,
    this.notes,
    required this.subtotal,
    required this.discountTotal,
    required this.taxAmount,
    required this.grandTotal,
    required this.paidAmount,
    required this.changeAmount,
    this.cashierId,
    this.cashierName,
    this.waiterId,
    this.waiterName,
    required this.items,
    this.diningOption = DiningOption.dineIn,
    this.kitchenStatus = KitchenStatus.pending,
    required this.discounts,
    required this.payments,
    this.createdAt,
    this.updatedAt,
    this.paidAt,
    this.voidReason,
    this.voidedBy,
  });

  final String id;
  final String outletId;
  final String businessId;
  final String invoiceNumber;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final int? tableNumber;
  final DiningOption diningOption;
  final KitchenStatus kitchenStatus;
  final TransactionStatus status;
  final OrderSource orderSource;
  final String? notes;
  final double subtotal;
  final double discountTotal;
  final double taxAmount;
  final double grandTotal;
  final double paidAmount;
  final double changeAmount;
  final String? cashierId;
  final String? cashierName;
  final String? waiterId;
  final String? waiterName;
  final List<TransactionItem> items;
  final List<TransactionDiscount> discounts;
  final List<TransactionPayment> payments;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;
  final String? voidReason;
  final String? voidedBy;

  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  factory TransactionOrder.fromJson(Map<String, dynamic> json) {
    final orderStatus = TransactionStatus.fromDb(json['status'] as String?);

    return TransactionOrder(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      businessId: json['business_id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      tableNumber: json['table_number'] as int?,
      diningOption: DiningOption.fromDb(
        json['dining_option'] as String? ??
            (json['notes']?.toString().contains('[TAKEAWAY]') == true
                ? 'take_away'
                : json['notes']?.toString().contains('[DELIVERY]') == true
                ? 'delivery'
                : json['notes']?.toString().contains('[GOFOOD]') == true
                ? 'gofood'
                : json['notes']?.toString().contains('[GRABFOOD]') == true
                ? 'grabfood'
                : json['notes']?.toString().contains('[SHOPEEFOOD]') == true
                ? 'shopeefood'
                : json['notes']?.toString().contains('[CUSTOM]') == true
                ? 'custom'
                : 'dine_in'),
      ),
      status: orderStatus,
      orderSource: OrderSource.fromDb(json['order_source'] as String?),
      notes: json['notes'] as String?,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discountTotal: (json['discount_total'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      changeAmount: (json['change_amount'] as num?)?.toDouble() ?? 0,
      cashierId: json['cashier_id'] as String?,
      cashierName: json['cashier_name'] as String?,
      waiterId: json['waiter_id'] as String?,
      waiterName: json['waiter_name'] as String?,
      items:
          (json['order_items'] as List<dynamic>?)
              ?.map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      discounts:
          (json['order_discounts'] as List<dynamic>?)
              ?.map(
                (e) => TransactionDiscount.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      payments:
          (json['order_payments'] as List<dynamic>?)
              ?.map(
                (e) => TransactionPayment.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      kitchenStatus: KitchenStatus.fromDb(
        json['kitchen_status'] as String? ??
            (json['notes']?.toString().contains('[KITCHEN:COOKING]') == true
                ? 'cooking'
                : json['notes']?.toString().contains('[KITCHEN:READY]') == true
                ? 'ready'
                : json['notes']?.toString().contains('[KITCHEN:SERVED]') == true
                ? 'served'
                : (orderStatus == TransactionStatus.paid
                      ? 'served'
                      : 'pending')),
      ),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      paidAt: _parseDateTime(json['paid_at']),
      voidReason: json['void_reason'] as String?,
      voidedBy: json['voided_by'] as String?,
    );
  }

  /// Catatan pesanan bersih tanpa tag tipe konsumsi ([TAKEAWAY], [DELIVERY], dsb)
  String? get displayNotes {
    if (notes == null) return null;
    final cleaned = notes!
        .replaceAll(
          RegExp(r'\[(TAKEAWAY|DELIVERY|GOFOOD|GRABFOOD|SHOPEEFOOD|CUSTOM)\]'),
          '',
        )
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  Map<String, dynamic> toOrderJson() {
    // Sisipkan tag tipe konsumsi ke notes agar backward-compatible jika kolom dining_option belum ada di DB
    String? enrichedNotes = notes;
    if (diningOption != DiningOption.dineIn) {
      final tag = switch (diningOption) {
        DiningOption.takeAway => '[TAKEAWAY]',
        DiningOption.delivery => '[DELIVERY]',
        DiningOption.goFood => '[GOFOOD]',
        DiningOption.grabFood => '[GRABFOOD]',
        DiningOption.shopeeFood => '[SHOPEEFOOD]',
        DiningOption.custom => '[CUSTOM]',
        DiningOption.dineIn => '',
      };
      if (tag.isNotEmpty && !(enrichedNotes?.contains(tag) ?? false)) {
        enrichedNotes = (enrichedNotes == null || enrichedNotes.trim().isEmpty)
            ? tag
            : '$tag $enrichedNotes';
      }
    }

    return {
      'id': id,
      'outlet_id': outletId,
      'business_id': businessId,
      'invoice_number': invoiceNumber,
      if (customerName != null && customerName!.trim().isNotEmpty)
        'customer_name': customerName!.trim(),
      if (customerPhone != null && customerPhone!.trim().isNotEmpty)
        'customer_phone': customerPhone!.trim(),
      if (customerEmail != null && customerEmail!.trim().isNotEmpty)
        'customer_email': customerEmail!.trim(),
      if (tableNumber != null) 'table_number': tableNumber,
      'dining_option': diningOption.dbValue,
      'status': status.dbValue,
      'order_source': orderSource.dbValue,
      'notes': enrichedNotes,
      'subtotal': subtotal.roundToDouble() == subtotal
          ? subtotal.round()
          : subtotal,
      'discount_total': discountTotal.roundToDouble() == discountTotal
          ? discountTotal.round()
          : discountTotal,
      'tax_amount': taxAmount.roundToDouble() == taxAmount
          ? taxAmount.round()
          : taxAmount,
      'grand_total': grandTotal.roundToDouble() == grandTotal
          ? grandTotal.round()
          : grandTotal,
      'paid_amount': paidAmount.roundToDouble() == paidAmount
          ? paidAmount.round()
          : paidAmount,
      'change_amount': changeAmount.roundToDouble() == changeAmount
          ? changeAmount.round()
          : changeAmount,
      if (cashierId != null && cashierId!.trim().isNotEmpty)
        'cashier_id': cashierId!.trim(),
      if (cashierName != null && cashierName!.trim().isNotEmpty)
        'cashier_name': cashierName!.trim(),
      if (waiterId != null && waiterId!.trim().isNotEmpty)
        'waiter_id': waiterId!.trim(),
      if (waiterName != null && waiterName!.trim().isNotEmpty)
        'waiter_name': waiterName!.trim(),
      'kitchen_status': kitchenStatus.dbValue,
      'paid_at': paidAt?.toUtc().toIso8601String(),
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      if (voidReason != null && voidReason!.trim().isNotEmpty)
        'void_reason': voidReason!.trim(),
      if (voidedBy != null && voidedBy!.trim().isNotEmpty)
        'voided_by': voidedBy!.trim(),
    };
  }

  TransactionOrder copyWith({
    String? id,
    String? outletId,
    String? businessId,
    String? invoiceNumber,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    int? tableNumber,
    DiningOption? diningOption,
    KitchenStatus? kitchenStatus,
    TransactionStatus? status,
    OrderSource? orderSource,
    String? notes,
    double? subtotal,
    double? discountTotal,
    double? taxAmount,
    double? grandTotal,
    double? paidAmount,
    double? changeAmount,
    String? cashierId,
    String? cashierName,
    String? waiterId,
    String? waiterName,
    List<TransactionItem>? items,
    List<TransactionDiscount>? discounts,
    List<TransactionPayment>? payments,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
    String? voidReason,
    String? voidedBy,
  }) {
    return TransactionOrder(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      businessId: businessId ?? this.businessId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      tableNumber: tableNumber ?? this.tableNumber,
      diningOption: diningOption ?? this.diningOption,
      kitchenStatus: kitchenStatus ?? this.kitchenStatus,
      status: status ?? this.status,
      orderSource: orderSource ?? this.orderSource,
      notes: notes ?? this.notes,
      subtotal: subtotal ?? this.subtotal,
      discountTotal: discountTotal ?? this.discountTotal,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      waiterId: waiterId ?? this.waiterId,
      waiterName: waiterName ?? this.waiterName,
      items: items ?? this.items,
      discounts: discounts ?? this.discounts,
      payments: payments ?? this.payments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
      voidReason: voidReason ?? this.voidReason,
      voidedBy: voidedBy ?? this.voidedBy,
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

/// Model metode pembayaran outlet (read from outlet_payment_methods table).
class PaymentMethodOption {
  const PaymentMethodOption({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.provider,
    this.accountLabel,
    this.accountNumber,
    this.instructions,
    required this.isActive,
    required this.sortOrder,
    required this.requiresReference,
    required this.allowsChange,
  });

  final String id;
  final String code;
  final String name;
  final String type;
  final String? provider;
  final String? accountLabel;
  final String? accountNumber;
  final String? instructions;
  final bool isActive;
  final int sortOrder;
  final bool requiresReference;
  final bool allowsChange;

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    return PaymentMethodOption(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'custom',
      provider: json['provider'] as String?,
      accountLabel: json['account_label'] as String?,
      accountNumber: json['account_number'] as String?,
      instructions: json['instructions'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      requiresReference: json['requires_reference'] as bool? ?? false,
      allowsChange: json['allows_change'] as bool? ?? false,
    );
  }
}
