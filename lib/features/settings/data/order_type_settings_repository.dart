import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderTypeConfig {
  static const _defaultCodes = {'dine_in', 'take_away', 'gofood', 'grabfood', 'shopeefood', 'delivery'};

  const OrderTypeConfig({
    required this.id,
    required this.outletId,
    required this.code,
    required this.name,
    this.icon = 'restaurant',
    this.requiresTable = false,
    this.isActive = true,
    this.sortOrder = 0,
    this.surchargePercentage = 0,
    this.surchargeFlat = 0,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String outletId;
  final String code;
  final String name;
  final String icon;
  final bool requiresTable;
  final bool isActive;
  final int sortOrder;
  final double surchargePercentage;
  final double surchargeFlat;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isSystemDefault => _defaultCodes.contains(code);

  IconData get iconData {
    return switch (icon) {
      'shopping_bag' => Icons.shopping_bag_outlined,
      'motorcycle' => Icons.two_wheeler_rounded,
      'delivery_dining' => Icons.delivery_dining_rounded,
      'storefront' => Icons.storefront_rounded,
      'coffee' => Icons.local_cafe_rounded,
      'fastfood' => Icons.fastfood_rounded,
      'celebration' => Icons.celebration_rounded,
      _ => Icons.restaurant_rounded,
    };
  }

  String get emoji {
    return switch (icon) {
      'shopping_bag' => '🥡',
      'motorcycle' => '🛵',
      'delivery_dining' => '🚚',
      'storefront' => '🏪',
      'coffee' => '☕',
      'fastfood' => '🍔',
      'celebration' => '🎉',
      _ => '🍽️',
    };
  }

  OrderTypeConfig copyWith({
    String? id,
    String? outletId,
    String? code,
    String? name,
    String? icon,
    bool? requiresTable,
    bool? isActive,
    int? sortOrder,
    double? surchargePercentage,
    double? surchargeFlat,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderTypeConfig(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      code: code ?? this.code,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      requiresTable: requiresTable ?? this.requiresTable,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      surchargePercentage: surchargePercentage ?? this.surchargePercentage,
      surchargeFlat: surchargeFlat ?? this.surchargeFlat,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory OrderTypeConfig.fromJson(Map<String, dynamic> json) {
    return OrderTypeConfig(
      id: json['id'] as String,
      outletId: json['outlet_id'] as String,
      code: json['code'] as String? ?? 'custom',
      name: json['name'] as String? ?? 'Tipe Pesanan',
      icon: json['icon'] as String? ?? 'restaurant',
      requiresTable: json['requires_table'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      surchargePercentage: (json['surcharge_percentage'] as num?)?.toDouble() ?? 0,
      surchargeFlat: (json['surcharge_flat'] as num?)?.toDouble() ?? 0,
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : const {},
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString())?.toLocal() : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'outlet_id': outletId,
      'code': normalizeCode(code),
      'name': name.trim(),
      'icon': icon,
      'requires_table': requiresTable,
      'is_active': isActive,
      'sort_order': sortOrder,
      'surcharge_percentage': surchargePercentage,
      'surcharge_flat': surchargeFlat,
      'metadata': metadata,
    };
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

  static List<OrderTypeConfig> defaultListForOutlet(String outletId) {
    return [
      OrderTypeConfig(
        id: 'default-dine-in',
        outletId: outletId,
        code: 'dine_in',
        name: 'Makan di Tempat',
        icon: 'restaurant',
        requiresTable: true,
        isActive: true,
        sortOrder: 0,
      ),
      OrderTypeConfig(
        id: 'default-take-away',
        outletId: outletId,
        code: 'take_away',
        name: 'Bawa Pulang',
        icon: 'shopping_bag',
        requiresTable: false,
        isActive: true,
        sortOrder: 10,
      ),
      OrderTypeConfig(
        id: 'default-gofood',
        outletId: outletId,
        code: 'gofood',
        name: 'GoFood',
        icon: 'motorcycle',
        requiresTable: false,
        isActive: true,
        sortOrder: 20,
      ),
      OrderTypeConfig(
        id: 'default-grabfood',
        outletId: outletId,
        code: 'grabfood',
        name: 'GrabFood',
        icon: 'motorcycle',
        requiresTable: false,
        isActive: true,
        sortOrder: 30,
      ),
      OrderTypeConfig(
        id: 'default-shopeefood',
        outletId: outletId,
        code: 'shopeefood',
        name: 'ShopeeFood',
        icon: 'motorcycle',
        requiresTable: false,
        isActive: true,
        sortOrder: 40,
      ),
      OrderTypeConfig(
        id: 'default-delivery',
        outletId: outletId,
        code: 'delivery',
        name: 'Pesan Antar',
        icon: 'delivery_dining',
        requiresTable: false,
        isActive: true,
        sortOrder: 50,
      ),
    ];
  }
}

class OrderTypeSettingsRepository {
  OrderTypeSettingsRepository(this._client);

  final SupabaseClient _client;
  static const _tableName = 'outlet_order_types';

  Future<List<OrderTypeConfig>> getOrderTypes(String outletId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('outlet_id', outletId)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final items = (response as List<dynamic>)
          .map((json) => OrderTypeConfig.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      if (items.isNotEmpty) {
        return items;
      }

      // If empty in DB, try to seed defaults
      await ensureDefaultOrderTypes(outletId);
      final seeded = await _client
          .from(_tableName)
          .select()
          .eq('outlet_id', outletId)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      return (seeded as List<dynamic>)
          .map((json) => OrderTypeConfig.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      debugPrint('[OrderTypeSettingsRepository] Fetch error, returning fallback: $e');
      return OrderTypeConfig.defaultListForOutlet(outletId);
    }
  }

  Future<void> ensureDefaultOrderTypes(String outletId) async {
    try {
      final defaults = OrderTypeConfig.defaultListForOutlet(outletId);
      for (final item in defaults) {
        await _client.from(_tableName).upsert(
          item.toInsertJson(),
          onConflict: 'outlet_id,code',
        );
      }
    } catch (e) {
      debugPrint('[OrderTypeSettingsRepository] ensureDefaultOrderTypes error: $e');
    }
  }

  Future<OrderTypeConfig> saveOrderType(OrderTypeConfig config) async {
    final payload = config.toInsertJson();
    if (config.id.startsWith('default-') || config.id.isEmpty) {
      final res = await _client
          .from(_tableName)
          .insert(payload)
          .select()
          .single();
      return OrderTypeConfig.fromJson(Map<String, dynamic>.from(res));
    } else {
      final res = await _client
          .from(_tableName)
          .update(payload)
          .eq('id', config.id)
          .select()
          .single();
      return OrderTypeConfig.fromJson(Map<String, dynamic>.from(res));
    }
  }

  Future<void> deleteOrderType(String id) async {
    await _client.from(_tableName).delete().eq('id', id);
  }

  Future<void> toggleActive(String id, bool isActive) async {
    await _client.from(_tableName).update({'is_active': isActive}).eq('id', id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIVERPOD PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final orderTypeSettingsRepositoryProvider = Provider<OrderTypeSettingsRepository>((ref) {
  return OrderTypeSettingsRepository(SupabaseService.client);
});

final orderTypesProvider = AsyncNotifierProvider<OrderTypesNotifier, List<OrderTypeConfig>>(
  OrderTypesNotifier.new,
);

class OrderTypesNotifier extends AsyncNotifier<List<OrderTypeConfig>> {
  @override
  Future<List<OrderTypeConfig>> build() async {
    final bootstrap = ref.watch(homeBootstrapProvider).value;
    final outletId = bootstrap?.currentOutlet?.id;
    if (outletId == null) {
      return OrderTypeConfig.defaultListForOutlet('');
    }
    return ref.read(orderTypeSettingsRepositoryProvider).getOrderTypes(outletId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final bootstrap = ref.read(homeBootstrapProvider).value;
      final outletId = bootstrap?.currentOutlet?.id;
      if (outletId == null) return OrderTypeConfig.defaultListForOutlet('');
      return ref.read(orderTypeSettingsRepositoryProvider).getOrderTypes(outletId);
    });
  }

  Future<void> saveOrderType(OrderTypeConfig config) async {
    await ref.read(orderTypeSettingsRepositoryProvider).saveOrderType(config);
    await refresh();
  }

  Future<void> deleteOrderType(String id) async {
    await ref.read(orderTypeSettingsRepositoryProvider).deleteOrderType(id);
    await refresh();
  }

  Future<void> toggleActive(String id, bool isActive) async {
    // Optimistic update
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((item) => item.id == id ? item.copyWith(isActive: isActive) : item).toList(),
    );

    try {
      await ref.read(orderTypeSettingsRepositoryProvider).toggleActive(id, isActive);
    } catch (e) {
      await refresh();
      rethrow;
    }
  }
}

final activeOrderTypesProvider = Provider<List<OrderTypeConfig>>((ref) {
  final all = ref.watch(orderTypesProvider).value ?? [];
  final active = all.where((o) => o.isActive).toList();
  if (active.isEmpty) {
    return OrderTypeConfig.defaultListForOutlet('').where((o) => o.isActive).toList();
  }
  return active;
});

final canManageOrderTypesProvider = Provider<bool>((ref) {
  final bootstrap = ref.watch(homeBootstrapProvider).value;
  final role = bootstrap?.effectiveRole?.name.toLowerCase();
  return role == 'owner' || role == 'admin' || role == 'manager';
});
