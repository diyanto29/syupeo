enum DiscountType {
  percentage,
  fixedAmount;

  static DiscountType fromValue(String? value) {
    switch (value) {
      case 'fixed_amount':
        return DiscountType.fixedAmount;
      case 'percentage':
      default:
        return DiscountType.percentage;
    }
  }

  String get dbValue {
    switch (this) {
      case DiscountType.percentage:
        return 'percentage';
      case DiscountType.fixedAmount:
        return 'fixed_amount';
    }
  }

  String get label {
    switch (this) {
      case DiscountType.percentage:
        return 'Percentage';
      case DiscountType.fixedAmount:
        return 'Rupiah';
    }
  }

  String get helperText {
    switch (this) {
      case DiscountType.percentage:
        return 'Potongan dihitung dari persentase, opsional dengan batas maksimal rupiah.';
      case DiscountType.fixedAmount:
        return 'Potongan langsung dengan nominal rupiah tetap.';
    }
  }
}

class DiscountDefinition {
  static const _unset = Object();

  const DiscountDefinition({
    required this.id,
    required this.businessId,
    required this.name,
    required this.type,
    this.code,
    this.description,
    this.percentageValue,
    this.amountValue,
    this.maxDiscountAmount,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? code;
  final String? description;
  final DiscountType type;
  final double? percentageValue;
  final double? amountValue;
  final double? maxDiscountAmount;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasSchedule => startsAt != null || endsAt != null;

  bool get usesMaxDiscount =>
      type == DiscountType.percentage &&
      maxDiscountAmount != null &&
      maxDiscountAmount! > 0;

  bool get isUpcoming {
    if (!isActive || startsAt == null) {
      return false;
    }
    return DateTime.now().isBefore(startsAt!);
  }

  bool get isExpired {
    if (endsAt == null) {
      return false;
    }
    return DateTime.now().isAfter(endsAt!);
  }

  bool get isAvailableNow {
    if (!isActive || isUpcoming || isExpired) {
      return false;
    }
    return true;
  }

  double get configuredValue {
    switch (type) {
      case DiscountType.percentage:
        return percentageValue ?? 0;
      case DiscountType.fixedAmount:
        return amountValue ?? 0;
    }
  }

  DiscountDefinition copyWith({
    String? id,
    String? businessId,
    String? name,
    Object? code = _unset,
    Object? description = _unset,
    DiscountType? type,
    Object? percentageValue = _unset,
    Object? amountValue = _unset,
    Object? maxDiscountAmount = _unset,
    bool? isActive,
    Object? startsAt = _unset,
    Object? endsAt = _unset,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
  }) {
    return DiscountDefinition(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      code: identical(code, _unset) ? this.code : code as String?,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      type: type ?? this.type,
      percentageValue: identical(percentageValue, _unset)
          ? this.percentageValue
          : percentageValue as double?,
      amountValue: identical(amountValue, _unset)
          ? this.amountValue
          : amountValue as double?,
      maxDiscountAmount: identical(maxDiscountAmount, _unset)
          ? this.maxDiscountAmount
          : maxDiscountAmount as double?,
      isActive: isActive ?? this.isActive,
      startsAt: identical(startsAt, _unset)
          ? this.startsAt
          : startsAt as DateTime?,
      endsAt: identical(endsAt, _unset) ? this.endsAt : endsAt as DateTime?,
      createdAt: identical(createdAt, _unset)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  factory DiscountDefinition.fromJson(Map<String, dynamic> json) {
    return DiscountDefinition(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      code: _sanitizeNullableText(json['code'] as String?),
      description: _sanitizeNullableText(json['description'] as String?),
      type: DiscountType.fromValue(json['type'] as String?),
      percentageValue: (json['percentage_value'] as num?)?.toDouble(),
      amountValue: (json['amount_value'] as num?)?.toDouble(),
      maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      startsAt: _parseDateTime(json['starts_at']),
      endsAt: _parseDateTime(json['ends_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name.trim(),
      'code': _sanitizeNullableText(code),
      'description': _sanitizeNullableText(description),
      'type': type.dbValue,
      'percentage_value': type == DiscountType.percentage
          ? percentageValue
          : null,
      'amount_value': type == DiscountType.fixedAmount ? amountValue : null,
      'max_discount_amount': type == DiscountType.percentage
          ? maxDiscountAmount
          : null,
      'is_active': isActive,
      'starts_at': startsAt?.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
    };
  }

  static String? _sanitizeNullableText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toLocal();
  }
}
