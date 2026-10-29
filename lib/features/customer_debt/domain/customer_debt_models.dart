class Customer {
  final String id;
  final String businessId;
  final String name;
  final String phone;
  final String? address;
  final double creditLimit;
  final double currentDebt;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Customer({
    required this.id,
    required this.businessId,
    required this.name,
    required this.phone,
    this.address,
    this.creditLimit = 0,
    this.currentDebt = 0,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  bool get hasDebt => currentDebt > 0;
  bool get hasLimit => creditLimit > 0;
  bool get isOverLimit => hasLimit && currentDebt > creditLimit;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String? ?? 'Pelanggan',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'phone': phone,
      'address': address,
      'credit_limit': creditLimit,
      'current_debt': currentDebt,
      'notes': notes,
    };
  }
}

enum DebtStatus {
  unpaid('Belum Lunas'),
  partiallyPaid('Dicicil Sebagian'),
  paid('Lunas'),
  badDebt('Macet / Hangus');

  final String label;
  const DebtStatus(this.label);

  static DebtStatus fromString(String? val) {
    return switch (val) {
      'partially_paid' => DebtStatus.partiallyPaid,
      'paid' => DebtStatus.paid,
      'bad_debt' => DebtStatus.badDebt,
      _ => DebtStatus.unpaid,
    };
  }

  String toDbValue() {
    return switch (this) {
      DebtStatus.partiallyPaid => 'partially_paid',
      DebtStatus.paid => 'paid',
      DebtStatus.badDebt => 'bad_debt',
      DebtStatus.unpaid => 'unpaid',
    };
  }
}

class CustomerDebt {
  final String id;
  final String businessId;
  final String outletId;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String? orderId;
  final String? invoiceNumber;
  final double totalAmount;
  final double remainingAmount;
  final DateTime? dueDate;
  final DebtStatus status;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const CustomerDebt({
    required this.id,
    required this.businessId,
    required this.outletId,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    this.orderId,
    this.invoiceNumber,
    required this.totalAmount,
    required this.remainingAmount,
    this.dueDate,
    this.status = DebtStatus.unpaid,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPaid => status == DebtStatus.paid || remainingAmount <= 0;
  
  bool get isOverdue {
    if (isPaid || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  bool get isDueToday {
    if (isPaid || dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  int? get overdueDays {
    if (dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final diff = today.difference(due).inDays;
    return diff > 0 ? diff : null;
  }

  factory CustomerDebt.fromJson(Map<String, dynamic> json) {
    final customerData = json['customers'] as Map<String, dynamic>?;

    return CustomerDebt(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      outletId: json['outlet_id'] as String,
      customerId: json['customer_id'] as String,
      customerName: customerData != null ? customerData['name'] as String? : null,
      customerPhone: customerData != null ? customerData['phone'] as String? : null,
      orderId: json['order_id'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      status: DebtStatus.fromString(json['status'] as String?),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
    );
  }
}

class DebtPayment {
  final String id;
  final String debtId;
  final String customerId;
  final String outletId;
  final String? shiftId;
  final double amountPaid;
  final String paymentMethod;
  final String? notes;
  final String? receivedBy;
  final DateTime createdAt;

  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.customerId,
    required this.outletId,
    this.shiftId,
    required this.amountPaid,
    this.paymentMethod = 'cash',
    this.notes,
    this.receivedBy,
    required this.createdAt,
  });

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as String,
      debtId: json['debt_id'] as String,
      customerId: json['customer_id'] as String,
      outletId: json['outlet_id'] as String,
      shiftId: json['shift_id'] as String?,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      notes: json['notes'] as String?,
      receivedBy: json['received_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }
}
