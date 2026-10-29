import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PaymentMethodType {
  cash,
  card,
  qris,
  bankTransfer,
  eWallet,
  custom;

  static PaymentMethodType fromValue(String? value) {
    switch (value) {
      case 'cash':
        return PaymentMethodType.cash;
      case 'card':
        return PaymentMethodType.card;
      case 'qris':
        return PaymentMethodType.qris;
      case 'bank_transfer':
        return PaymentMethodType.bankTransfer;
      case 'e_wallet':
        return PaymentMethodType.eWallet;
      case 'custom':
      default:
        return PaymentMethodType.custom;
    }
  }

  String get dbValue {
    switch (this) {
      case PaymentMethodType.cash:
        return 'cash';
      case PaymentMethodType.card:
        return 'card';
      case PaymentMethodType.qris:
        return 'qris';
      case PaymentMethodType.bankTransfer:
        return 'bank_transfer';
      case PaymentMethodType.eWallet:
        return 'e_wallet';
      case PaymentMethodType.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethodType.cash:
        return 'Cash';
      case PaymentMethodType.card:
        return 'Kartu';
      case PaymentMethodType.qris:
        return 'QRIS';
      case PaymentMethodType.bankTransfer:
        return 'Transfer Bank';
      case PaymentMethodType.eWallet:
        return 'E-Wallet';
      case PaymentMethodType.custom:
        return 'Custom';
    }
  }
}

class PaymentMethodConfig {
  static const _unset = Object();
  static const _defaultCodes = {'cash', 'debit_credit', 'qris'};

  const PaymentMethodConfig({
    required this.id,
    required this.outletId,
    required this.code,
    required this.name,
    required this.type,
    this.provider,
    this.accountLabel,
    this.accountNumber,
    this.instructions,
    this.isActive = true,
    this.sortOrder = 0,
    this.requiresReference = false,
    this.allowsChange = false,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String outletId;
  final String code;
  final String name;
  final PaymentMethodType type;
  final String? provider;
  final String? accountLabel;
  final String? accountNumber;
  final String? instructions;
  final bool isActive;
  final int sortOrder;
  final bool requiresReference;
  final bool allowsChange;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isSystemDefault => _defaultCodes.contains(code);

  String get displaySubtitle {
    final pieces = <String>[type.label];
    final providerName = provider?.trim();
    if (providerName != null && providerName.isNotEmpty) {
      pieces.add(providerName);
    }
    if (requiresReference) {
      pieces.add('butuh referensi');
    }
    if (allowsChange) {
      pieces.add('kembalian');
    }
    return pieces.join(' • ');
  }

  PaymentMethodConfig copyWith({
    String? id,
    String? outletId,
    String? code,
    String? name,
    PaymentMethodType? type,
    Object? provider = _unset,
    Object? accountLabel = _unset,
    Object? accountNumber = _unset,
    Object? instructions = _unset,
    bool? isActive,
    int? sortOrder,
    bool? requiresReference,
    bool? allowsChange,
    Map<String, dynamic>? metadata,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
  }) {
    return PaymentMethodConfig(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      provider: identical(provider, _unset)
          ? this.provider
          : provider as String?,
      accountLabel: identical(accountLabel, _unset)
          ? this.accountLabel
          : accountLabel as String?,
      accountNumber: identical(accountNumber, _unset)
          ? this.accountNumber
          : accountNumber as String?,
      instructions: identical(instructions, _unset)
          ? this.instructions
          : instructions as String?,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      requiresReference: requiresReference ?? this.requiresReference,
      allowsChange: allowsChange ?? this.allowsChange,
      metadata: metadata ?? this.metadata,
      createdAt: identical(createdAt, _unset)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  factory PaymentMethodConfig.fromJson(Map<String, dynamic> json) {
    return PaymentMethodConfig(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      type: PaymentMethodType.fromValue(json['type'] as String?),
      provider: _sanitizeNullableText(json['provider'] as String?),
      accountLabel: _sanitizeNullableText(json['account_label'] as String?),
      accountNumber: _sanitizeNullableText(json['account_number'] as String?),
      instructions: _sanitizeNullableText(json['instructions'] as String?),
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      requiresReference: json['requires_reference'] as bool? ?? false,
      allowsChange: json['allows_change'] as bool? ?? false,
      metadata: _mapFromJson(json['metadata']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'code': normalizeCode(code),
      'name': name.trim(),
      'type': type.dbValue,
      'provider': _sanitizeNullableText(provider),
      'account_label': _sanitizeNullableText(accountLabel),
      'account_number': _sanitizeNullableText(accountNumber),
      'instructions': _sanitizeNullableText(instructions),
      'is_active': isActive,
      'sort_order': sortOrder,
      'requires_reference': requiresReference,
      'allows_change': allowsChange,
      'metadata': metadata,
    };
  }

  static List<Map<String, dynamic>> defaultRowsForOutlet(String outletId) {
    return [
      {
        'outlet_id': outletId,
        'code': 'cash',
        'name': 'Cash',
        'type': PaymentMethodType.cash.dbValue,
        'is_active': true,
        'sort_order': 0,
        'requires_reference': false,
        'allows_change': true,
      },
      {
        'outlet_id': outletId,
        'code': 'debit_credit',
        'name': 'Debit/Credit',
        'type': PaymentMethodType.card.dbValue,
        'is_active': true,
        'sort_order': 10,
        'requires_reference': true,
        'allows_change': false,
      },
      {
        'outlet_id': outletId,
        'code': 'qris',
        'name': 'QRIS',
        'type': PaymentMethodType.qris.dbValue,
        'provider': 'QRIS',
        'is_active': true,
        'sort_order': 20,
        'requires_reference': true,
        'allows_change': false,
      },
    ];
  }

  static String normalizeCode(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String? _sanitizeNullableText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, dynamic> _mapFromJson(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toLocal();
  }
}

class PaymentSettingsRepository {
  PaymentSettingsRepository(this._client);

  final SupabaseClient _client;
  static const _tableName = 'outlet_payment_methods';

  Future<List<PaymentMethodConfig>> getPaymentMethods(String outletId) async {
    final response = await _client
        .from(_tableName)
        .select()
        .eq('outlet_id', outletId)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);

    final methods = (response as List<dynamic>)
        .map(
          (json) => PaymentMethodConfig.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();

    if (methods.isNotEmpty) {
      return methods;
    }

    await ensureDefaultMethods(outletId);
    final seededResponse = await _client
        .from(_tableName)
        .select()
        .eq('outlet_id', outletId)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);

    return (seededResponse as List<dynamic>)
        .map(
          (json) => PaymentMethodConfig.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();
  }

  Future<void> ensureDefaultMethods(String outletId) async {
    await _client
        .from(_tableName)
        .upsert(
          PaymentMethodConfig.defaultRowsForOutlet(outletId),
          onConflict: 'outlet_id,code',
          ignoreDuplicates: true,
          defaultToNull: false,
        );
  }

  Future<void> upsertPaymentMethod(PaymentMethodConfig method) async {
    await _client.from(_tableName).upsert(method.toJson());
  }

  Future<void> deletePaymentMethod(String id) async {
    await _client.from(_tableName).delete().eq('id', id);
  }
}

final paymentSettingsRepositoryProvider = Provider<PaymentSettingsRepository>((
  ref,
) {
  return PaymentSettingsRepository(SupabaseService.client);
});

final paymentMethodsProvider =
    AsyncNotifierProvider<PaymentMethodsNotifier, List<PaymentMethodConfig>>(
      () => PaymentMethodsNotifier(),
    );

final canManagePaymentSettingsProvider = Provider<bool>((ref) {
  final role = ref.watch(homeBootstrapProvider).value?.effectiveRole;
  return role == AppRole.owner || role == AppRole.admin;
});

class PaymentMethodsNotifier extends AsyncNotifier<List<PaymentMethodConfig>> {
  @override
  Future<List<PaymentMethodConfig>> build() async {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final outletId = bootstrap?.currentOutlet?.id;

    if (outletId == null) {
      return [];
    }

    return ref
        .watch(paymentSettingsRepositoryProvider)
        .getPaymentMethods(outletId);
  }

  String? get _outletId =>
      ref.read(homeBootstrapProvider).value?.currentOutlet?.id;

  Future<void> refresh() async {
    final outletId = _outletId;
    if (outletId == null) {
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(paymentSettingsRepositoryProvider)
          .getPaymentMethods(outletId),
    );
  }

  Future<void> saveMethod(PaymentMethodConfig method) async {
    final outletId = _outletId;
    if (outletId == null) {
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(paymentSettingsRepositoryProvider)
            .upsertPaymentMethod(method.copyWith(outletId: outletId));
        return await ref
            .read(paymentSettingsRepositoryProvider)
            .getPaymentMethods(outletId);
      } catch (error, stackTrace) {
        debugPrint('Error saving payment method: $error');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });
  }

  Future<void> deleteMethod(PaymentMethodConfig method) async {
    final outletId = _outletId;
    if (outletId == null || method.isSystemDefault) {
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(paymentSettingsRepositoryProvider)
            .deletePaymentMethod(method.id);
        return await ref
            .read(paymentSettingsRepositoryProvider)
            .getPaymentMethods(outletId);
      } catch (error, stackTrace) {
        debugPrint('Error deleting payment method: $error');
        debugPrint('Stack trace: $stackTrace');
        rethrow;
      }
    });
  }
}
