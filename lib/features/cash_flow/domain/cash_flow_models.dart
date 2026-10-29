/// Status sesi shift kasir
enum CashShiftStatus {
  open,
  closed;

  static CashShiftStatus fromString(String value) {
    return value.toLowerCase() == 'closed' ? CashShiftStatus.closed : CashShiftStatus.open;
  }

  String get label => this == CashShiftStatus.open ? 'Aktif (Buka)' : 'Selesai (Tutup)';
}

/// Tipe mutasi kas
enum CashFlowType {
  cashIn,
  cashOut;

  static CashFlowType fromString(String value) {
    return value.toLowerCase() == 'in' ? CashFlowType.cashIn : CashFlowType.cashOut;
  }

  String get value => this == CashFlowType.cashIn ? 'in' : 'out';
  String get label => this == CashFlowType.cashIn ? 'Kas Masuk' : 'Kas Keluar';
}

/// Model Shift Kasir (Buka/Tutup Kas & Rekonsiliasi)
class CashShift {
  final String id;
  final String businessId;
  final String outletId;
  final String? cashierId;
  final String cashierName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double startingCash;
  final double? expectedCash;
  final double? actualCash;
  final double? differenceAmount;
  final double totalSalesCash;
  final double totalCashIn;
  final double totalCashOut;
  final CashShiftStatus status;
  final String? notes;

  const CashShift({
    required this.id,
    required this.businessId,
    required this.outletId,
    this.cashierId,
    required this.cashierName,
    required this.openedAt,
    this.closedAt,
    this.startingCash = 0,
    this.expectedCash,
    this.actualCash,
    this.differenceAmount,
    this.totalSalesCash = 0,
    this.totalCashIn = 0,
    this.totalCashOut = 0,
    this.status = CashShiftStatus.open,
    this.notes,
  });

  bool get isOpen => status == CashShiftStatus.open;
  bool get isClosed => status == CashShiftStatus.closed;

  /// Estimasi saldo kas di laci saat ini
  double get estimatedDrawerCash =>
      startingCash + totalSalesCash + totalCashIn - totalCashOut;

  /// Cek selisih uang
  bool get hasDifference => (differenceAmount ?? 0).abs() > 0.01;
  bool get isSurplus => (differenceAmount ?? 0) > 0.01;
  bool get isDeficit => (differenceAmount ?? 0) < -0.01;

  factory CashShift.fromJson(Map<String, dynamic> json) {
    DateTime rawOpened = DateTime.parse(json['opened_at'] as String);
    DateTime? rawClosed = json['closed_at'] != null ? DateTime.parse(json['closed_at'] as String) : null;

    rawOpened = sanitizeShiftTime(rawOpened).toLocal();
    if (rawClosed != null) {
      rawClosed = sanitizeShiftTime(rawClosed).toLocal();
    }

    return CashShift(
      id: json['id'] as String,
      businessId: json['business_id'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      cashierId: json['cashier_id'] as String?,
      cashierName: json['cashier_name'] as String? ?? 'Kasir',
      openedAt: rawOpened,
      closedAt: rawClosed,
      startingCash: (json['starting_cash'] as num?)?.toDouble() ?? 0,
      expectedCash: (json['expected_cash'] as num?)?.toDouble(),
      actualCash: (json['actual_cash'] as num?)?.toDouble(),
      differenceAmount: (json['difference_amount'] as num?)?.toDouble(),
      totalSalesCash: (json['total_sales_cash'] as num?)?.toDouble() ?? 0,
      totalCashIn: (json['total_cash_in'] as num?)?.toDouble() ?? 0,
      totalCashOut: (json['total_cash_out'] as num?)?.toDouble() ?? 0,
      status: CashShiftStatus.fromString(json['status'] as String? ?? 'open'),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'outlet_id': outletId,
      'cashier_id': cashierId,
      'cashier_name': cashierName,
      'opened_at': openedAt.toUtc().toIso8601String(),
      'closed_at': closedAt?.toUtc().toIso8601String(),
      'starting_cash': startingCash,
      'expected_cash': expectedCash,
      'actual_cash': actualCash,
      'difference_amount': differenceAmount,
      'total_sales_cash': totalSalesCash,
      'total_cash_in': totalCashIn,
      'total_cash_out': totalCashOut,
      'status': status.name,
      'notes': notes,
    };
  }
}

/// Helper untuk membersihkan dan menstandarkan timestamp shift bila tersimpan sebagai waktu lokal masa depan
DateTime sanitizeShiftTime(DateTime dt) {
  final nowUtc = DateTime.now().toUtc();
  // Jika timestamp lebih dari 5 menit di masa depan, berarti waktu lokal (e.g. WIB +7 jam)
  // tersimpan sebagai UTC tanpa konversi zona waktu yang tepat.
  if (dt.toUtc().isAfter(nowUtc.add(const Duration(minutes: 5)))) {
    final offset = DateTime.now().timeZoneOffset;
    final adjusted = dt.subtract(offset);
    if (adjusted.toUtc().isAfter(nowUtc.add(const Duration(minutes: 5)))) {
      return nowUtc;
    }
    return adjusted;
  }
  return dt;
}

/// Model Entri Arus Kas (Pemasukan / Pengeluaran Toko)
class CashFlowEntry {
  final String id;
  final String businessId;
  final String outletId;
  final String? shiftId;
  final String? cashierId;
  final String cashierName;
  final CashFlowType type;
  final String category;
  final double amount;
  final String paymentSource;
  final String? notes;
  final String? receiptUrl;
  final DateTime createdAt;

  const CashFlowEntry({
    required this.id,
    required this.businessId,
    required this.outletId,
    this.shiftId,
    this.cashierId,
    this.cashierName = 'Kasir',
    required this.type,
    required this.category,
    required this.amount,
    this.paymentSource = 'cash',
    this.notes,
    this.receiptUrl,
    required this.createdAt,
  });

  bool get isIncome => type == CashFlowType.cashIn;
  bool get isExpense => type == CashFlowType.cashOut;

  factory CashFlowEntry.fromJson(Map<String, dynamic> json) {
    DateTime rawCreated = DateTime.parse(json['created_at'] as String);
    rawCreated = sanitizeShiftTime(rawCreated).toLocal();

    return CashFlowEntry(
      id: json['id'] as String,
      businessId: json['business_id'] as String? ?? '',
      outletId: json['outlet_id'] as String? ?? '',
      shiftId: json['shift_id'] as String?,
      cashierId: json['cashier_id'] as String?,
      cashierName: json['cashier_name'] as String? ?? 'Kasir',
      type: CashFlowType.fromString(json['type'] as String? ?? 'out'),
      category: json['category'] as String? ?? 'Lain-lain',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentSource: json['payment_source'] as String? ?? 'cash',
      notes: json['notes'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      createdAt: rawCreated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'outlet_id': outletId,
      'shift_id': shiftId,
      'cashier_id': cashierId,
      'cashier_name': cashierName,
      'type': type.value,
      'category': category,
      'amount': amount,
      'payment_source': paymentSource,
      'notes': notes,
      'receipt_url': receiptUrl,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

/// Kategori bawaan pengeluaran & pemasukan
class CashCategories {
  static const List<String> expenseCategories = [
    'Bahan Baku & Dapur',
    'Kemasan & Plastik',
    'Operasional & Kebersihan',
    'Listrik, Gas & Utilitas',
    'Uang Makan & Lembur',
    'Prive (Tarik Uang Owner)',
    'Perawatan & Servis',
    'Pengembalian Dana / Refund',
    'Lain-lain',
  ];

  static const List<String> incomeCategories = [
    'Modal Tambahan',
    'Pendapatan Non-Menu',
    'Pengembalian Dana / Refund',
    'Lain-lain',
  ];
}
