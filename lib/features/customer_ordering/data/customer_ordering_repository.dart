import 'dart:convert';

import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/core/domain/outlet_models.dart';
import 'package:dpos/features/transaction/domain/transaction_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef CustomerOrderHistoryArgs = ({String outletId, String tableId});

const _maxStoredCustomerOrders = 20;

class CustomerOrderingRepository {
  CustomerOrderingRepository(this._client);
  final SupabaseClient _client;

  String _historyStorageKey(String outletId, String tableId) {
    return 'customer_order_history:$outletId:$tableId';
  }

  String _historySnapshotStorageKey(String outletId, String tableId) {
    return 'customer_order_history_snapshot:$outletId:$tableId';
  }

  Future<Outlet?> getOutletById(String id) async {
    final response = await _client
        .from('outlets')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Outlet.fromMap(response);
  }

  Future<List<MenuItem>> getMenuItemsByBusinessId(String businessId) async {
    final response = await _client
        .from('menu_items')
        .select(
          '*, menu_category:menu_categories!menu_items_category_id_fkey(*), menu_item_variants(*)',
        )
        .eq('business_id', businessId)
        .eq('stock_available', true)
        .order('name', ascending: true);

    return (response as List<dynamic>)
        .map((json) => MenuItem.fromJson(json as Map<String, dynamic>))
        .where((item) => item.isSellable)
        .toList();
  }

  Future<String> submitSelfOrder({
    required String outletId,
    required String tableId,
    required int? tableNumber,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    required List<TransactionItem> items,
  }) async {
    if (items.isEmpty) {
      throw StateError('Keranjang pesanan kosong.');
    }

    final payload = <Map<String, dynamic>>[];
    for (final item in items) {
      final menuItemId = item.menuItemId;
      if (menuItemId == null || menuItemId.isEmpty) {
        throw StateError('Item ${item.name} tidak valid untuk disimpan.');
      }
      payload.add({
        'menu_item_id': menuItemId,
        'variant_id': item.variantId,
        'quantity': item.quantity,
        'notes': item.notes,
      });
    }

    final tableKey = _normalizeTableKey(tableId, tableNumber);
    final legacyParams = {
      'target_outlet_id': outletId,
      'target_table_number': tableNumber,
      'target_customer_name': customerName?.trim(),
      'target_customer_phone': customerPhone?.trim(),
      'target_customer_email': customerEmail?.trim(),
      'items_payload': payload,
    };

    dynamic response;
    try {
      response = await _client.rpc(
        'create_self_order',
        params: {...legacyParams, 'target_table_key': tableKey},
      );
    } on PostgrestException catch (error) {
      if (!_isRpcSignatureError(error)) rethrow;

      response = await _client.rpc('create_self_order', params: legacyParams);
    }

    if (response is String && response.isNotEmpty) {
      await _rememberOrderLocally(
        outletId: outletId,
        tableId: tableId,
        orderId: response,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        tableNumber: tableNumber,
        subtotal: items.fold(0, (sum, item) => sum + item.rawSubtotal),
        items: items,
      );
      return response;
    }

    final orderId = response.toString();
    await _rememberOrderLocally(
      outletId: outletId,
      tableId: tableId,
      orderId: orderId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      tableNumber: tableNumber,
      subtotal: items.fold(0, (sum, item) => sum + item.rawSubtotal),
      items: items,
    );
    return orderId;
  }

  Future<void> _rememberOrderLocally({
    required String outletId,
    required String tableId,
    required String orderId,
    required String? customerName,
    required String? customerPhone,
    required String? customerEmail,
    required int? tableNumber,
    required double subtotal,
    required List<TransactionItem> items,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final idKey = _historyStorageKey(outletId, tableId);
    final snapshotKey = _historySnapshotStorageKey(outletId, tableId);
    final existing = prefs.getStringList(idKey) ?? const [];
    final updated = [
      orderId,
      ...existing.where((storedId) => storedId != orderId),
    ].take(_maxStoredCustomerOrders).toList();
    await prefs.setStringList(idKey, updated);

    final snapshots = await _getStoredOrderSnapshots(
      outletId: outletId,
      tableId: tableId,
    );
    Map<String, dynamic>? previousSnapshot;
    for (final snapshot in snapshots) {
      if (snapshot['id'] == orderId) {
        previousSnapshot = Map<String, dynamic>.from(snapshot);
        break;
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final existingItems =
        (previousSnapshot?['order_items'] as List<dynamic>?)
            ?.map((item) => Map<String, dynamic>.from(item as Map))
            .toList() ??
        const <Map<String, dynamic>>[];
    final newItems = items.map((item) => item.toJson(orderId)).toList();
    final previousSubtotal =
        (previousSnapshot?['subtotal'] as num?)?.toDouble() ?? 0;
    final mergedSubtotal = previousSubtotal + subtotal;
    final safeOrderCode = orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();

    final localOrder = <String, dynamic>{
      'id': orderId,
      'outlet_id': outletId,
      'business_id': previousSnapshot?['business_id'] ?? '',
      'invoice_number':
          previousSnapshot?['invoice_number'] ?? 'PESANAN-$safeOrderCode',
      'customer_name': previousSnapshot?['customer_name'] ?? customerName,
      'customer_phone': previousSnapshot?['customer_phone'] ?? customerPhone,
      'customer_email': previousSnapshot?['customer_email'] ?? customerEmail,
      'table_number': tableNumber,
      'status': TransactionStatus.confirmed.dbValue,
      'order_source': OrderSource.qrSelfOrder.dbValue,
      'notes': null,
      'subtotal': mergedSubtotal,
      'discount_total': 0,
      'tax_amount': 0,
      'grand_total': mergedSubtotal,
      'paid_amount': 0,
      'change_amount': 0,
      'cashier_id': null,
      'cashier_name': null,
      'waiter_id': null,
      'waiter_name': null,
      'created_at': previousSnapshot?['created_at'] ?? now,
      'updated_at': now,
      'paid_at': null,
      'order_items': [...existingItems, ...newItems],
      'order_discounts': const [],
      'order_payments': const [],
    };

    final updatedSnapshots = [
      localOrder,
      ...snapshots
          .where((snapshot) => snapshot['id'] != orderId)
          .map((snapshot) => Map<String, dynamic>.from(snapshot)),
    ].take(_maxStoredCustomerOrders).toList();

    await prefs.setString(snapshotKey, jsonEncode(updatedSnapshots));
  }

  Future<List<String>> getStoredOrderIds({
    required String outletId,
    required String tableId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyStorageKey(outletId, tableId)) ??
        const [];
  }

  Future<List<TransactionOrder>> getSelfOrderHistory({
    required String outletId,
    required String tableId,
  }) async {
    final localSnapshots = await getStoredOrderSnapshots(
      outletId: outletId,
      tableId: tableId,
    );
    final storedOrderIds = await getStoredOrderIds(
      outletId: outletId,
      tableId: tableId,
    );

    try {
      dynamic response;
      try {
        response = await _client.rpc(
          'get_self_order_history',
          params: {
            'target_outlet_id': outletId,
            'known_order_ids': storedOrderIds,
            'target_table_key': _normalizeTableKey(
              tableId,
              int.tryParse(tableId),
            ),
            'target_table_number': int.tryParse(tableId),
          },
        );
      } on PostgrestException catch (error) {
        if (!_isRpcSignatureError(error)) rethrow;
        if (storedOrderIds.isEmpty) {
          return localSnapshots;
        }

        response = await _client.rpc(
          'get_self_order_history',
          params: {
            'target_outlet_id': outletId,
            'known_order_ids': storedOrderIds,
          },
        );
      }

      if (response is! List) {
        return localSnapshots;
      }

      final serverOrders = response
          .map(
            (json) => TransactionOrder.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();

      if (localSnapshots.isEmpty) {
        return serverOrders;
      }

      final merged = <String, TransactionOrder>{
        for (final order in localSnapshots) order.id: order,
        for (final order in serverOrders) order.id: order,
      };

      final orders = merged.values.toList()
        ..sort((a, b) {
          final aDate =
              a.updatedAt ?? a.createdAt ?? a.paidAt ?? DateTime(2000);
          final bDate =
              b.updatedAt ?? b.createdAt ?? b.paidAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
      return orders;
    } catch (_) {
      return localSnapshots;
    }
  }

  Future<List<TransactionOrder>> getStoredOrderSnapshots({
    required String outletId,
    required String tableId,
  }) async {
    final snapshots = await _getStoredOrderSnapshots(
      outletId: outletId,
      tableId: tableId,
    );

    return snapshots
        .map(
          (json) => TransactionOrder.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList()
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? a.paidAt ?? DateTime(2000);
        final bDate = b.updatedAt ?? b.createdAt ?? b.paidAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
  }

  Future<List<Map<String, dynamic>>> _getStoredOrderSnapshots({
    required String outletId,
    required String tableId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historySnapshotStorageKey(outletId, tableId));
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  String? _normalizeTableKey(String tableId, int? tableNumber) {
    final trimmed = tableId.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return tableNumber?.toString();
  }

  bool _isRpcSignatureError(PostgrestException error) {
    final message =
        '${error.message} ${error.details} ${error.hint} ${error.code}'
            .toLowerCase();
    return message.contains('could not find the function') ||
        message.contains('schema cache') ||
        message.contains('target_table_key') ||
        message.contains('pgrst202');
  }
}

final customerOrderingRepositoryProvider = Provider<CustomerOrderingRepository>(
  (ref) {
    return CustomerOrderingRepository(SupabaseService.client);
  },
);

final customerOutletProvider = FutureProvider.family<Outlet?, String>((
  ref,
  outletId,
) {
  return ref.read(customerOrderingRepositoryProvider).getOutletById(outletId);
});

final customerMenuProvider = FutureProvider.family<List<MenuItem>, String>((
  ref,
  businessId,
) {
  return ref
      .read(customerOrderingRepositoryProvider)
      .getMenuItemsByBusinessId(businessId);
});

final customerOrderHistoryProvider =
    FutureProvider.family<List<TransactionOrder>, CustomerOrderHistoryArgs>((
      ref,
      args,
    ) {
      return ref
          .read(customerOrderingRepositoryProvider)
          .getSelfOrderHistory(outletId: args.outletId, tableId: args.tableId);
    });
